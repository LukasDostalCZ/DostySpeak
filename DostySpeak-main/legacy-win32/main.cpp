#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif

#include <windows.h>
#include <sapi.h>
#include <commctrl.h>
#include <string>
#include <vector>

static HWND g_main = nullptr;
static HWND g_input = nullptr;
static HWND g_list = nullptr;
static HWND g_volume = nullptr;
static HWND g_speed = nullptr;
static ISpVoice *g_voice = nullptr;
static WNDPROC g_oldInputProc = nullptr;
static WNDPROC g_oldListProc = nullptr;

static std::vector<std::wstring> g_phrases = {
    L"Dobrý den, omlouvám se, momentálně nemůžu mluvit.",
    L"Prosím zopakujte to pomaleji.",
    L"Děkuji, rozumím.",
    L"Potřebuji chvíli na napsání odpovědi.",
    L"Prosím chvilku, napíšu odpověď."
};

static void refreshList() {
    SendMessageW(g_list, LB_RESETCONTENT, 0, 0);
    for (const auto &p : g_phrases) {
        SendMessageW(g_list, LB_ADDSTRING, 0, reinterpret_cast<LPARAM>(p.c_str()));
    }
}

static std::wstring getWindowTextWide(HWND hwnd) {
    int len = GetWindowTextLengthW(hwnd);
    std::wstring text(len, L'\0');
    GetWindowTextW(hwnd, text.data(), len + 1);
    return text;
}

static void speak(const std::wstring &text) {
    if (text.empty()) return;

    if (!g_voice) {
        HRESULT hr = CoCreateInstance(CLSID_SpVoice, nullptr, CLSCTX_ALL, IID_ISpVoice, reinterpret_cast<void **>(&g_voice));
        if (FAILED(hr) || !g_voice) {
            MessageBoxW(nullptr, L"Nepodařilo se spustit Windows SAPI hlas.", L"Dosty Speak Legacy", MB_ICONERROR);
            return;
        }
    }

    int vol = static_cast<int>(SendMessageW(g_volume, TBM_GETPOS, 0, 0));
    int rateSlider = static_cast<int>(SendMessageW(g_speed, TBM_GETPOS, 0, 0));
    int rate = rateSlider - 10;

    g_voice->SetVolume(static_cast<USHORT>(vol));
    g_voice->SetRate(rate);
    g_voice->Speak(text.c_str(), SPF_ASYNC | SPF_PURGEBEFORESPEAK, nullptr);
}

static void speakCurrentInput() {
    speak(getWindowTextWide(g_input));
}

static void speakSelectedPhrase() {
    int idx = static_cast<int>(SendMessageW(g_list, LB_GETCURSEL, 0, 0));
    if (idx >= 0 && idx < static_cast<int>(g_phrases.size())) {
        SetWindowTextW(g_input, g_phrases[idx].c_str());
        speak(g_phrases[idx]);
    } else {
        speakCurrentInput();
    }
}

static void savePhrase() {
    std::wstring text = getWindowTextWide(g_input);
    if (text.empty()) return;
    g_phrases.push_back(text);
    refreshList();
}

static LRESULT CALLBACK InputProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    if (msg == WM_KEYDOWN) {
        if (wParam == VK_RETURN) {
            speakCurrentInput();
            return 0;
        }
        if (wParam == VK_TAB) {
            SetFocus(g_list);
            return 0;
        }
    }
    return CallWindowProcW(g_oldInputProc, hwnd, msg, wParam, lParam);
}

static LRESULT CALLBACK ListProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    if (msg == WM_KEYDOWN) {
        if (wParam == VK_RETURN) {
            speakSelectedPhrase();
            return 0;
        }
        if (wParam == VK_TAB) {
            SetFocus(g_input);
            SendMessageW(g_input, EM_SETSEL, 0, -1);
            return 0;
        }
    }
    return CallWindowProcW(g_oldListProc, hwnd, msg, wParam, lParam);
}

static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_CREATE: {
        g_main = hwnd;
        HFONT font = reinterpret_cast<HFONT>(GetStockObject(DEFAULT_GUI_FONT));

        CreateWindowW(L"STATIC", L"Dosty Speak Legacy", WS_CHILD | WS_VISIBLE,
                      16, 12, 260, 24, hwnd, nullptr, nullptr, nullptr);

        g_input = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"Prosím chvilku, napíšu odpověď.",
                                  WS_CHILD | WS_VISIBLE | WS_TABSTOP | ES_AUTOHSCROLL,
                                  16, 48, 500, 28, hwnd, reinterpret_cast<HMENU>(100), nullptr, nullptr);

        HWND speakBtn = CreateWindowW(L"BUTTON", L"Přečíst", WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
                                      528, 48, 88, 28, hwnd, reinterpret_cast<HMENU>(101), nullptr, nullptr);

        HWND saveBtn = CreateWindowW(L"BUTTON", L"Uložit", WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
                                     624, 48, 88, 28, hwnd, reinterpret_cast<HMENU>(102), nullptr, nullptr);

        g_list = CreateWindowExW(WS_EX_CLIENTEDGE, L"LISTBOX", nullptr,
                                 WS_CHILD | WS_VISIBLE | WS_TABSTOP | LBS_NOTIFY | WS_VSCROLL,
                                 16, 96, 500, 270, hwnd, reinterpret_cast<HMENU>(103), nullptr, nullptr);

        CreateWindowW(L"STATIC", L"Hlasitost", WS_CHILD | WS_VISIBLE,
                      540, 108, 160, 20, hwnd, nullptr, nullptr, nullptr);
        g_volume = CreateWindowW(TRACKBAR_CLASSW, nullptr, WS_CHILD | WS_VISIBLE | WS_TABSTOP | TBS_AUTOTICKS,
                                 540, 132, 170, 32, hwnd, reinterpret_cast<HMENU>(104), nullptr, nullptr);
        SendMessageW(g_volume, TBM_SETRANGE, TRUE, MAKELPARAM(0, 100));
        SendMessageW(g_volume, TBM_SETPOS, TRUE, 100);

        CreateWindowW(L"STATIC", L"Rychlost", WS_CHILD | WS_VISIBLE,
                      540, 188, 160, 20, hwnd, nullptr, nullptr, nullptr);
        g_speed = CreateWindowW(TRACKBAR_CLASSW, nullptr, WS_CHILD | WS_VISIBLE | WS_TABSTOP | TBS_AUTOTICKS,
                                540, 212, 170, 32, hwnd, reinterpret_cast<HMENU>(105), nullptr, nullptr);
        SendMessageW(g_speed, TBM_SETRANGE, TRUE, MAKELPARAM(0, 20));
        SendMessageW(g_speed, TBM_SETPOS, TRUE, 10);

        HWND hint = CreateWindowW(L"STATIC",
                                  L"Tab přepíná psaní/seznam. Enter čte aktivní text nebo vybranou hlášku.",
                                  WS_CHILD | WS_VISIBLE,
                                  16, 382, 710, 24, hwnd, nullptr, nullptr, nullptr);

        HWND controls[] = {g_input, speakBtn, saveBtn, g_list, g_volume, g_speed, hint};
        for (HWND c : controls) SendMessageW(c, WM_SETFONT, reinterpret_cast<WPARAM>(font), TRUE);

        g_oldInputProc = reinterpret_cast<WNDPROC>(SetWindowLongPtrW(g_input, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(InputProc)));
        g_oldListProc = reinterpret_cast<WNDPROC>(SetWindowLongPtrW(g_list, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(ListProc)));

        refreshList();
        SetFocus(g_input);
        return 0;
    }

    case WM_COMMAND:
        if (LOWORD(wParam) == 101) {
            speakCurrentInput();
            return 0;
        }
        if (LOWORD(wParam) == 102) {
            savePhrase();
            return 0;
        }
        if (LOWORD(wParam) == 103 && HIWORD(wParam) == LBN_DBLCLK) {
            speakSelectedPhrase();
            return 0;
        }
        break;

    case WM_DESTROY:
        if (g_voice) {
            g_voice->Release();
            g_voice = nullptr;
        }
        CoUninitialize();
        PostQuitMessage(0);
        return 0;
    }

    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE, PWSTR, int nCmdShow) {
    CoInitialize(nullptr);

    INITCOMMONCONTROLSEX icc{};
    icc.dwSize = sizeof(icc);
    icc.dwICC = ICC_BAR_CLASSES;
    InitCommonControlsEx(&icc);

    const wchar_t CLASS_NAME[] = L"DostySpeakLegacyWin32";

    WNDCLASSW wc{};
    wc.lpfnWndProc = WndProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = CLASS_NAME;
    wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wc.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);

    RegisterClassW(&wc);

    HWND hwnd = CreateWindowExW(
        0,
        CLASS_NAME,
        L"Dosty Speak Legacy",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, 760, 470,
        nullptr, nullptr, hInstance, nullptr
    );

    if (!hwnd) return 0;

    ShowWindow(hwnd, nCmdShow);
    UpdateWindow(hwnd);

    MSG msg{};
    while (GetMessageW(&msg, nullptr, 0, 0)) {
        if (!IsDialogMessageW(hwnd, &msg)) {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
    }

    return 0;
}
