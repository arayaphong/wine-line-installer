#!/usr/bin/env python3
"""Build the offline LINE payload from pinned program files and local assets."""

from argparse import ArgumentParser
import gzip
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tarfile
import tempfile
from zipfile import ZipFile


PHASE = Path(__file__).resolve().parent
PROJECT = PHASE.parents[1]
PROGRAM_EXTRAS = {
    PurePosixPath("bin/LineLauncher.exe"),
    PurePosixPath("bin/LineUnInst.exe"),
    PurePosixPath("Data/installLang.ini"),
}


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def extract_program(stage, line):
    version = line["version"]
    source = line["post_install_snapshot"]
    snapshot = PROJECT / source["path"]
    if sha256(snapshot) != source["sha256"]:
        raise ValueError("LINE snapshot checksum differs from the phase 1 inventory")

    references = source["versioned_bin_references"]
    source_root = PurePosixPath(references["LINE.exe"]["archive_member"]).parents[2]
    selected = set()
    versioned_count = 0
    versioned_bytes = 0
    with subprocess.Popen(["unzstd", "-c", str(snapshot)], stdout=subprocess.PIPE) as decoder:
        with tarfile.open(fileobj=decoder.stdout, mode="r|") as contents:
            for member in contents:
                path = PurePosixPath(member.name)
                if not path.is_relative_to(source_root) or member.isdir():
                    continue
                relative = path.relative_to(source_root)
                versioned = relative.parts[:2] == ("bin", version)
                if not versioned and relative not in PROGRAM_EXTRAS:
                    continue
                if ".." in relative.parts or not member.isfile() or relative in selected:
                    raise ValueError(f"Unexpected snapshot entry: {relative}")
                target = stage / "line" / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                with contents.extractfile(member) as original, target.open("xb") as output:
                    shutil.copyfileobj(original, output)
                selected.add(relative)
                if versioned:
                    versioned_count += 1
                    versioned_bytes += member.size
        # The compressed stream may have archive padding after the end-of-tar marker.
        while decoder.stdout.read(1024 * 1024):
            pass
        if decoder.wait() != 0:
            raise RuntimeError("Could not decompress the LINE snapshot")

    counts = source["member_counts"]
    if (versioned_count, versioned_bytes) != (counts["versioned_bin_files"], counts["versioned_bin_bytes"]):
        raise ValueError("Versioned LINE files differ from the phase 1 inventory")
    if not PROGRAM_EXTRAS <= selected or (stage / "line/Data/installLang.ini").read_bytes() != b"installLang=th":
        raise ValueError("Unexpected launcher, uninstaller, or installation language files")
    for name, expected in references.items():
        if sha256(stage / "line/bin" / version / name) != expected["sha256"]:
            raise ValueError(f"LINE file checksum differs from the phase 1 inventory: {name}")
    return len(selected)


def copy_installed_program(stage, line, installed_dir):
    source = installed_dir.resolve(strict=True)
    version = line["version"]
    entries = {}
    for row in (PHASE / "payload-files.sha256").read_text().splitlines():
        digest, _, name = row.partition("  ")
        if not name.startswith("line/"):
            continue
        relative = PurePosixPath(name).relative_to("line")
        if (
            ".." in relative.parts
            or relative in entries
            or (relative.parts[:2] != ("bin", version) and relative not in PROGRAM_EXTRAS)
        ):
            raise ValueError(f"Unexpected program manifest entry: {name}")
        entries[relative] = digest

    snapshot = line["post_install_snapshot"]
    expected_count = snapshot["member_counts"]["versioned_bin_files"] + len(PROGRAM_EXTRAS)
    if len(entries) != expected_count or not PROGRAM_EXTRAS <= entries.keys():
        raise ValueError("The pinned program manifest is incomplete")
    for name, reference in snapshot["versioned_bin_references"].items():
        if entries.get(PurePosixPath("bin", version, name)) != reference["sha256"]:
            raise ValueError(f"Program manifest differs from the phase 1 inventory: {name}")

    for relative, digest in entries.items():
        target = stage / "line" / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if relative == PurePosixPath("Data/installLang.ini"):
            target.write_bytes(b"installLang=th")
        else:
            original = (source / relative).resolve(strict=True)
            if not original.is_relative_to(source) or not original.is_file():
                raise ValueError(f"Program file is outside the selected installation: {relative}")
            shutil.copyfile(original, target)
        if sha256(target) != digest:
            raise ValueError(f"Installed LINE file differs from the pinned version: {relative}")
    return len(entries)


def extract_media_player(stage, media, media_player_zip):
    archive = media["archive"]
    source = media_player_zip or (PROJECT / archive["path"])
    if not source.is_file():
        raise FileNotFoundError(f"Missing official media player archive at {source}. Use --media-player-zip.")
    if source.stat().st_size != archive["size_bytes"] or sha256(source) != archive["sha256"]:
        raise ValueError("Media player archive checksum differs from the phase 1 inventory")
    manifest = PROJECT / media["manifest"]
    if sha256(manifest) != media["manifest_sha256"]:
        raise ValueError("Media player manifest checksum differs from the phase 1 inventory")

    destination = stage / "line-media-player" / media["version"]
    seen = set()
    total_bytes = 0
    with ZipFile(source) as zipped:
        for row in manifest.read_text().splitlines():
            digest, _, name = row.partition("  ")
            relative = PurePosixPath(name)
            if not name or relative.is_absolute() or ".." in relative.parts or relative in seen:
                raise ValueError(f"Unexpected media player manifest entry: {name}")
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            with zipped.open(name) as original, target.open("xb") as output:
                shutil.copyfileobj(original, output)
            if sha256(target) != digest:
                raise ValueError(f"Media player file differs from the pinned version: {relative}")
            total_bytes += target.stat().st_size
            seen.add(relative)

    if (len(seen), total_bytes) != (media["program_files"], media["program_bytes"]):
        raise ValueError("Media player files differ from the phase 1 inventory")
    if sha256(destination / "LineMediaPlayer.exe") != media["executable_sha256"]:
        raise ValueError("Media player executable checksum differs from the phase 1 inventory")
    return len(seen)


def build(installed_line_dir=None, media_player_zip=None):
    inventory = json.loads((PHASE.parent / "phase1/inventory.json").read_text())
    line = inventory["line_payload"]
    archive_name = f"line-{line['version']}.payload.tar.gz"
    dlls = inventory["dll_and_catalogs"]
    support_files = dlls["microsoft_x86"] + dlls["microsoft_x64_on_disk"]

    with tempfile.TemporaryDirectory(prefix=".payload-", dir=PHASE) as temporary:
        work = Path(temporary)
        stage = work / "files"
        if installed_line_dir is None:
            program_files = extract_program(stage, line)
        else:
            program_files = copy_installed_program(stage, line, installed_line_dir)
        media_files = extract_media_player(stage, line["media_player"], media_player_zip)
        for entry in support_files:
            source = PROJECT / entry["path"]
            if source.stat().st_size != entry["size_bytes"] or sha256(source) != entry["sha256"]:
                raise ValueError(f"DLL or catalog differs from the phase 1 inventory: {entry['path']}")
            target = stage / entry["path"]
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)

        thai_source = PHASE.parent / "phase4/thai-fonts"
        thai_target = stage / "fonts/thai"
        thai_target.mkdir(parents=True)
        for entry in inventory["font_candidates"]:
            if entry["role_in_test_set"] == "thai-sample":
                source = thai_source / Path(entry["path"]).name
                if sha256(source) != entry["sha256"]:
                    raise ValueError(f"Thai font differs from the phase 1 inventory: {source.name}")
                shutil.copyfile(source, thai_target / source.name)
        shutil.copyfile(thai_source / "OFL.txt", thai_target / "OFL.txt")

        emoji = next(entry for entry in inventory["font_candidates"] if entry["role_in_test_set"] == "color-probe")
        emoji_name = Path(emoji["path"]).name
        emoji_source = PHASE.parent / "phase4/emoji-fonts" / emoji_name
        if sha256(emoji_source) != emoji["sha256"]:
            raise ValueError(f"Emoji font differs from the phase 1 inventory: {emoji_name}")
        emoji_target = stage / "fonts/emoji"
        emoji_target.mkdir(parents=True)
        shutil.copyfile(emoji_source, emoji_target / emoji_name)

        files = sorted(path for path in stage.rglob("*") if path.is_file())
        index = stage / "SHA256SUMS"
        index.write_text("".join(f"{sha256(path)}  {path.relative_to(stage).as_posix()}\n" for path in files))
        archive = work / archive_name
        with archive.open("wb") as output:
            with gzip.GzipFile(fileobj=output, mode="wb", filename="", mtime=0) as compressed:
                with tarfile.open(fileobj=compressed, mode="w|") as payload:
                    for path in [index, *files]:
                        entry = payload.gettarinfo(str(path), arcname=path.relative_to(stage).as_posix())
                        entry.uid = entry.gid = entry.mtime = 0
                        entry.uname = entry.gname = ""
                        entry.mode = 0o755 if path.suffix.lower() == ".exe" else 0o644
                        with path.open("rb") as stream:
                            payload.addfile(entry, stream)
        archive_checksum = work / f"{archive_name}.sha256"
        archive_checksum.write_text(f"{sha256(archive)}  {archive_name}\n")
        archive.replace(PHASE / archive_name)
        archive_checksum.replace(PHASE / archive_checksum.name)
        index.replace(PHASE / "payload-files.sha256")
    print(f"Packed {program_files} LINE files, {media_files} media player files, "
          f"{len(support_files)} Microsoft DLL/catalog files, and Thai and emoji fonts")


if __name__ == "__main__":
    parser = ArgumentParser(description=__doc__)
    parser.add_argument(
        "--installed-line-dir", type=Path,
        help="AppData/Local/LINE directory from a clean installation of the pinned LINE version",
    )
    parser.add_argument(
        "--media-player-zip", type=Path,
        help="Official ZIP for the pinned LineMediaPlayer version, if stored outside baseline/inputs",
    )
    args = parser.parse_args()
    build(args.installed_line_dir, args.media_player_zip)
