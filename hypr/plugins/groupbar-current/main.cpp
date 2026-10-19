// Keep the group's currently shown tab styled as "active" even when the group is unfocused.
// Hyprland only paints col.active when the member == focusState()->window(); we override that
// look-up for the duration of CHyprGroupBarDecoration::draw to return group->current().

#define WLR_USE_UNSTABLE

#include <string>
#include <sstream>
#include <vector>

#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/plugins/HookSystem.hpp>
#include <hyprland/src/version.h>

// Access deco/window private fields for the focus override (hyprland-plugins do the same).
#pragma push_macro("private")
#ifdef private
#undef private
#endif
#define private public
#include <hyprland/src/render/decorations/CHyprGroupBarDecoration.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/desktop/view/Group.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#undef private
#pragma pop_macro("private")

inline HANDLE PHANDLE = nullptr;

static CFunctionHook* g_drawHook = nullptr;
static CFunctionHook* g_windowHook = nullptr;
static thread_local PHLWINDOW g_focusOverride = nullptr;

using DrawFn = void (*)(CHyprGroupBarDecoration*, PHLMONITOR, float const&);
using WindowFn = PHLWINDOW (*)(Desktop::CFocusState*);

static void hkDraw(CHyprGroupBarDecoration* self, PHLMONITOR monitor, float const& a) {
    PHLWINDOW prev = g_focusOverride;
    PHLWINDOW cur = nullptr;
    if (self && self->m_window) {
        auto win = self->m_window.lock();
        if (win && win->m_group)
            cur = win->m_group->current();
    }
    g_focusOverride = cur;
    ((DrawFn)g_drawHook->m_original)(self, monitor, a);
    g_focusOverride = prev;
}

static PHLWINDOW hkWindow(Desktop::CFocusState* self) {
    if (g_focusOverride)
        return g_focusOverride;
    return ((WindowFn)g_windowHook->m_original)(self);
}

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    PHANDLE = handle;

    auto version = HyprlandAPI::getHyprlandVersion(handle);
    // Soft check: still try to hook if the hash differs (headers match the package).

    auto drawFns = HyprlandAPI::findFunctionsByName(handle, "draw");
    CFunctionHook* drawHook = nullptr;
    for (auto& f : drawFns) {
        if (f.demangled.find("CHyprGroupBarDecoration") != std::string::npos &&
            f.demangled.find("draw") != std::string::npos) {
            drawHook = HyprlandAPI::createFunctionHook(handle, f.address, (void*)&hkDraw);
            break;
        }
    }

    auto windowFns = HyprlandAPI::findFunctionsByName(handle, "window");
    CFunctionHook* windowHook = nullptr;
    for (auto& f : windowFns) {
        // Desktop::CFocusState::window()
        if (f.demangled.find("CFocusState") != std::string::npos &&
            f.demangled.find("window") != std::string::npos &&
            f.demangled.find("isWindowActive") == std::string::npos) {
            windowHook = HyprlandAPI::createFunctionHook(handle, f.address, (void*)&hkWindow);
            break;
        }
    }

    if (!drawHook || !windowHook) {
        HyprlandAPI::addNotification(handle, "groupbar-current: failed to find hooks",
                                     CHyprColor{1.0, 0.4, 0.3, 1.0}, 5000);
        return {"groupbar-current", "keep groupbar selection when unfocused", "quantum-moon", "0.1.0"};
    }

    g_drawHook = drawHook;
    g_windowHook = windowHook;

    if (!(g_drawHook->hook() && g_windowHook->hook())) {
        HyprlandAPI::addNotification(handle, "groupbar-current: hook() failed",
                                     CHyprColor{1.0, 0.4, 0.3, 1.0}, 5000);
    }

    (void)version;
    return {"groupbar-current", "keep groupbar selection when unfocused", "quantum-moon", "0.1.0"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    // Hooks are removed by Hyprland after exit.
    g_drawHook = nullptr;
    g_windowHook = nullptr;
    g_focusOverride = nullptr;
}
