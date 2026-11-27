/* apply_delta.exe <basis|-> <delta> <out>
 * Applies a Windows MSDELTA (PA30) delta with msdelta.ApplyDeltaB. Run under Wine.
 * "-" as basis means an empty source. A 4-byte CRC prefix before "PA30" is skipped. */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct { const void *lpStart; SIZE_T uSize; BOOL Editable; } DELTA_INPUT;
typedef struct { void *lpStart; SIZE_T uSize; } DELTA_OUTPUT;
typedef BOOL (WINAPI *ApplyDeltaB_t)(LONGLONG, DELTA_INPUT, DELTA_INPUT, DELTA_OUTPUT *);
typedef BOOL (WINAPI *DeltaFree_t)(void *);

static BYTE *read_all(const char *path, SIZE_T *len)
{
    FILE *f = fopen(path, "rb");
    BYTE *buf;
    long n;
    if (!f) { fprintf(stderr, "cannot open %s\n", path); exit(1); }
    fseek(f, 0, SEEK_END); n = ftell(f); fseek(f, 0, SEEK_SET);
    buf = malloc(n ? n : 1);
    if (fread(buf, 1, n, f) != (size_t)n) { fprintf(stderr, "read error %s\n", path); exit(1); }
    fclose(f);
    *len = n;
    return buf;
}

int main(int argc, char **argv)
{
    HMODULE mod = LoadLibraryA("msdelta.dll");
    ApplyDeltaB_t apply = mod ? (ApplyDeltaB_t)GetProcAddress(mod, "ApplyDeltaB") : NULL;
    DeltaFree_t dfree = mod ? (DeltaFree_t)GetProcAddress(mod, "DeltaFree") : NULL;
    DELTA_INPUT src = {0}, delta = {0};
    DELTA_OUTPUT out = {0};
    SIZE_T slen = 0, dlen;
    BYTE *s = NULL, *d;
    FILE *f;

    if (argc != 4) { fprintf(stderr, "usage: apply_delta <basis|-> <delta> <out>\n"); return 2; }
    if (!apply) { fprintf(stderr, "msdelta.ApplyDeltaB not available\n"); return 1; }
    if (strcmp(argv[1], "-")) s = read_all(argv[1], &slen);
    d = read_all(argv[2], &dlen);
    if (dlen > 8 && !memcmp(d + 4, "PA30", 4)) { d += 4; dlen -= 4; }  /* CRC-prefixed delta */
    src.lpStart = s; src.uSize = slen;
    delta.lpStart = d; delta.uSize = dlen;
    if (!apply(0, src, delta, &out))
    {
        fprintf(stderr, "ApplyDeltaB failed: %lu\n", GetLastError());
        return 1;
    }
    f = fopen(argv[3], "wb");
    fwrite(out.lpStart, 1, out.uSize, f);
    fclose(f);
    printf("wrote %s (%lu bytes)\n", argv[3], (unsigned long)out.uSize);
    if (dfree) dfree(out.lpStart);
    return 0;
}
