/* winhttp_probe.exe [url]
 * Mimics LineInst.exe's download path (FUN_004022c0): WinHttpOpen("LINE Installer/1.0"),
 * Connect :443, OpenRequest GET with WINHTTP_FLAG_SECURE, Send, Receive, status, length, read.
 * Prints GetLastError() at each step. Run under Wine in the bottle. */
#include <windows.h>
#include <winhttp.h>
#include <stdio.h>

#ifndef ARRAY_SIZE
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#endif

#define STEP(name, expr) do { if (!(expr)) { printf("%-24s FAILED err=%lu\n", name, GetLastError()); return 1; } \
                              printf("%-24s ok\n", name); } while (0)

int wmain(int argc, WCHAR **argv)
{
    const WCHAR *url = argc > 1 ? argv[1] : L"https://desktop.line-scdn.net/win/bin/real/installer/installer.json";
    URL_COMPONENTS uc = { sizeof(uc) };
    WCHAR host[256], path[1024];
    HINTERNET ses, con, req;
    DWORD status = 0, len = sizeof(status), clen = 0, total = 0, avail, got, timeout = 30000;
    char buf[4096];

    uc.lpszHostName = host; uc.dwHostNameLength = ARRAY_SIZE(host);
    uc.lpszUrlPath = path; uc.dwUrlPathLength = ARRAY_SIZE(path);
    STEP("WinHttpCrackUrl", WinHttpCrackUrl(url, 0, 0, &uc));
    STEP("WinHttpOpen", ses = WinHttpOpen(L"LINE Installer/1.0", 0, NULL, NULL, 0));
    WinHttpSetTimeouts(ses, 10000, 10000, 10000, 10000);
    WinHttpSetOption(ses, 7, &timeout, sizeof(timeout));
    STEP("WinHttpConnect", con = WinHttpConnect(ses, host, 443, 0));
    STEP("WinHttpOpenRequest", req = WinHttpOpenRequest(con, L"GET", path, NULL, NULL, NULL, WINHTTP_FLAG_SECURE));
    STEP("WinHttpSendRequest", WinHttpSendRequest(req, NULL, 0, NULL, 0, 0, 0));
    STEP("WinHttpReceiveResponse", WinHttpReceiveResponse(req, NULL));
    STEP("QueryHeaders(status)", WinHttpQueryHeaders(req, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                                                       NULL, &status, &len, NULL));
    printf("status %lu\n", status);
    len = sizeof(clen);
    if (WinHttpQueryHeaders(req, WINHTTP_QUERY_CONTENT_LENGTH | WINHTTP_QUERY_FLAG_NUMBER, NULL, &clen, &len, NULL))
        printf("content-length %lu\n", clen);
    else
        printf("content-length query failed err=%lu\n", GetLastError());
    for (;;)
    {
        STEP("WinHttpQueryDataAvailable", WinHttpQueryDataAvailable(req, &avail));
        if (!avail) break;
        if (avail > sizeof(buf)) avail = sizeof(buf);
        STEP("WinHttpReadData", WinHttpReadData(req, buf, avail, &got));
        if (!total) printf("first bytes: %.*s\n", (int)(got < 120 ? got : 120), buf);
        total += got;
    }
    printf("total %lu bytes\n", total);
    return 0;
}
