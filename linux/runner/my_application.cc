#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include <bitsdojo_window_linux/bitsdojo_window_plugin.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

// --- Native context menu ---

// Pending method call – responded asynchronously when the menu closes.
static FlMethodCall* g_pending_call = nullptr;
// Stores the selected menu item id (set by the activate callback).
static gchar* g_selected_menu_id = nullptr;

static void context_menu_item_activated(GtkMenuItem* item, gpointer user_data) {
  g_free(g_selected_menu_id);
  const gchar* id = (const gchar*)g_object_get_data(G_OBJECT(item), "item-id");
  g_selected_menu_id = g_strdup(id);
}

// Deferred response – runs on the next main-loop idle after deactivate,
// so the item "activate" signal has already set g_selected_menu_id.
static gboolean on_menu_respond_idle(gpointer user_data) {
  if (g_pending_call == nullptr) return G_SOURCE_REMOVE;

  if (g_selected_menu_id != nullptr) {
    fl_method_call_respond_success(
        g_pending_call, fl_value_new_string(g_selected_menu_id), nullptr);
  } else {
    fl_method_call_respond_success(
        g_pending_call, fl_value_new_null(), nullptr);
  }

  g_object_unref(g_pending_call);
  g_pending_call = nullptr;
  return G_SOURCE_REMOVE;
}

// Called when the popup menu is dismissed (user picked an item or clicked away).
static void on_menu_deactivate(GtkMenuShell* menu, gpointer user_data) {
  // Defer to idle so that the item "activate" signal fires first.
  g_idle_add(on_menu_respond_idle, nullptr);
}

static void context_menu_method_call(FlMethodChannel* channel,
                                     FlMethodCall* method_call,
                                     gpointer user_data) {
  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "show") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    FlValue* items_val = fl_value_lookup_string(args, "items");
    if (items_val == nullptr || fl_value_get_type(items_val) != FL_VALUE_TYPE_LIST) {
      fl_method_call_respond_success(method_call, fl_value_new_null(), nullptr);
      return;
    }

    GtkMenu* menu = GTK_MENU(gtk_menu_new());
    size_t count = fl_value_get_length(items_val);

    for (size_t i = 0; i < count; i++) {
      FlValue* item = fl_value_get_list_value(items_val, i);
      FlValue* is_sep = fl_value_lookup_string(item, "isSeparator");
      if (is_sep != nullptr && fl_value_get_bool(is_sep)) {
        gtk_menu_shell_append(GTK_MENU_SHELL(menu),
                              gtk_separator_menu_item_new());
        continue;
      }

      FlValue* label_val = fl_value_lookup_string(item, "label");
      FlValue* id_val = fl_value_lookup_string(item, "id");
      FlValue* enabled_val = fl_value_lookup_string(item, "enabled");

      const gchar* label = label_val ? fl_value_get_string(label_val) : "";
      const gchar* id = id_val ? fl_value_get_string(id_val) : "";
      gboolean enabled = enabled_val ? fl_value_get_bool(enabled_val) : TRUE;

      GtkWidget* menu_item = gtk_menu_item_new_with_label(label);
      g_object_set_data_full(G_OBJECT(menu_item), "item-id",
                             g_strdup(id), g_free);
      gtk_widget_set_sensitive(menu_item, enabled);
      g_signal_connect(menu_item, "activate",
                       G_CALLBACK(context_menu_item_activated), nullptr);
      gtk_menu_shell_append(GTK_MENU_SHELL(menu), menu_item);
    }

    gtk_widget_show_all(GTK_WIDGET(menu));

    g_free(g_selected_menu_id);
    g_selected_menu_id = nullptr;

    // Hold on to the method call so we can respond from the deactivate callback.
    g_pending_call = FL_METHOD_CALL(g_object_ref(method_call));

    g_signal_connect(menu, "deactivate",
                     G_CALLBACK(on_menu_deactivate), nullptr);

    // Attach the menu to the Flutter view so it has a valid parent GdkWindow.
    GtkWidget* view = GTK_WIDGET(user_data);
    gtk_menu_attach_to_widget(menu, view, nullptr);

    // Use the deprecated gtk_menu_popup – it positions at the pointer without
    // requiring a GdkEvent (which Flutter consumes before GTK sees it).
    G_GNUC_BEGIN_IGNORE_DEPRECATIONS
    gtk_menu_popup(menu, nullptr, nullptr, nullptr, nullptr,
                   0, GDK_CURRENT_TIME);
    G_GNUC_END_IGNORE_DEPRECATIONS
    // Response happens asynchronously in on_menu_deactivate.
  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
  }
}

// --- End native context menu ---

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView *view)
{
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Custom frame: hide the native GTK title bar so the Flutter tab bar
  // can occupy that area, matching the macOS layout.
  gtk_window_set_title(window, "Bolan");
  auto bdw = bitsdojo_window_from(window);
  bdw->setCustomFrame(true);

  // Set window icon from the data directory relative to the executable.
  g_autofree gchar* real_exe = g_file_read_link("/proc/self/exe", nullptr);
  if (real_exe != nullptr) {
    g_autofree gchar* real_dir = g_path_get_dirname(real_exe);
    g_autofree gchar* icon_path = g_build_filename(real_dir, "data", "icons", "app_icon_256.png", nullptr);
    g_autoptr(GError) icon_error = nullptr;
    g_autoptr(GdkPixbuf) icon = gdk_pixbuf_new_from_file(icon_path, &icon_error);
    if (icon != nullptr) {
      gtk_window_set_icon(window, icon);
    }
  }

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000 for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb), self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // Register native context menu method channel.
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* context_menu_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "bolan/context_menu",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      context_menu_channel, context_menu_method_call,
      GTK_WIDGET(view), nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
