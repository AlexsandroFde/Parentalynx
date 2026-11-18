import 'package:material_ui/material_ui.dart';

/// Icones do app, nomeados pelo que significam.
///
/// Um unico estilo (contornado) em todo o app; a versao preenchida aparece so no item
/// selecionado da navegacao. O mesmo conceito usa sempre o mesmo icone: "bloqueado" e sempre
/// [blocked], "tempo extra" e sempre [extraTime]. As telas nao usam `Icons.` diretamente
/// (o teste do Design System confere).
abstract final class AppIcons {
  // Navegacao principal.
  static const IconData home = Icons.home_outlined;
  static const IconData homeSelected = Icons.home;
  static const IconData rules = Icons.tune;
  static const IconData rulesSelected = Icons.tune;
  static const IconData reports = Icons.bar_chart_outlined;
  static const IconData reportsSelected = Icons.bar_chart;
  static const IconData alerts = Icons.notifications_outlined;
  static const IconData alertsSelected = Icons.notifications;
  static const IconData more = Icons.more_horiz;
  static const IconData moreSelected = Icons.more_horiz;

  // Acoes e navegacao.
  static const IconData back = Icons.arrow_back_rounded;
  static const IconData forward = Icons.arrow_forward_rounded;
  static const IconData chevronRight = Icons.chevron_right;
  static const IconData chevronLeft = Icons.chevron_left;
  static const IconData expand = Icons.expand_more;
  static const IconData dropdown = Icons.arrow_drop_down;
  static const IconData close = Icons.close_rounded;
  static const IconData add = Icons.add;
  static const IconData addCircle = Icons.add_circle_outline;
  static const IconData removeCircle = Icons.remove_circle_outline;
  static const IconData edit = Icons.edit_outlined;
  static const IconData delete = Icons.delete_outline;
  static const IconData deleteForever = Icons.delete_forever_outlined;
  static const IconData clearAll = Icons.delete_sweep_outlined;
  static const IconData autoDelete = Icons.auto_delete_outlined;
  static const IconData refresh = Icons.refresh_rounded;
  static const IconData reset = Icons.restart_alt_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData filter = Icons.filter_list;
  static const IconData overflow = Icons.more_vert;
  static const IconData copy = Icons.copy_outlined;
  static const IconData copyAll = Icons.copy_all_outlined;
  static const IconData paste = Icons.content_paste_rounded;
  static const IconData share = Icons.share_outlined;
  static const IconData download = Icons.download_outlined;
  static const IconData send = Icons.send_rounded;
  static const IconData swap = Icons.swap_horiz;
  static const IconData signIn = Icons.login;
  static const IconData signOut = Icons.logout_rounded;
  static const IconData show = Icons.visibility_outlined;
  static const IconData hide = Icons.visibility_off_outlined;
  static const IconData check = Icons.check_rounded;
  static const IconData checkAll = Icons.done_all;
  static const IconData menu = Icons.menu;

  // Estados e avisos.
  static const IconData success = Icons.check_circle_outline;
  static const IconData successFilled = Icons.check_circle;
  static const IconData info = Icons.info_outline;
  static const IconData help = Icons.help_outline;
  static const IconData warning = Icons.warning_amber_rounded;
  static const IconData error = Icons.error_outline;
  static const IconData errorFilled = Icons.error;
  static const IconData problem = Icons.report_problem_outlined;
  static const IconData attention = Icons.priority_high_rounded;
  static const IconData pending = Icons.hourglass_empty;
  static const IconData cancelled = Icons.cancel_outlined;
  static const IconData radioOn = Icons.radio_button_checked;
  static const IconData radioOff = Icons.radio_button_unchecked;

  // Sincronizacao e conexao.
  static const IconData sync = Icons.sync;
  static const IconData syncProblem = Icons.sync_problem;
  static const IconData synced = Icons.cloud_done_outlined;
  static const IconData offline = Icons.cloud_off_outlined;
  static const IconData online = Icons.wifi;
  static const IconData server = Icons.dns_outlined;

  // Tempo e horarios.
  static const IconData dailyLimit = Icons.timer_outlined;
  static const IconData noLimit = Icons.timer_off_outlined;
  static const IconData extraTime = Icons.more_time;
  static const IconData timeRequest = Icons.more_time;
  static const IconData clock = Icons.schedule;
  static const IconData allowedHours = Icons.schedule;
  static const IconData bedtime = Icons.bedtime_outlined;
  static const IconData blockPeriod = Icons.event_busy_outlined;
  static const IconData calendar = Icons.event_outlined;
  static const IconData repeat = Icons.event_repeat_outlined;
  static const IconData available = Icons.event_available_outlined;
  static const IconData timeRunningOut = Icons.hourglass_bottom;
  static const IconData timeStarting = Icons.hourglass_top_rounded;
  static const IconData elapsed = Icons.timelapse;
  static const IconData alarm = Icons.alarm_rounded;
  static const IconData morning = Icons.wb_sunny_outlined;

  // Regras e controle.
  static const IconData apps = Icons.apps_outlined;
  static const IconData blocked = Icons.block;
  static const IconData allowed = Icons.check_circle_outline;
  static const IconData exception = Icons.verified_outlined;
  static const IconData essential = Icons.emergency_outlined;
  static const IconData pause = Icons.pause_circle_outline;
  static const IconData resume = Icons.play_circle_outline;
  static const IconData play = Icons.play_arrow;
  static const IconData lock = Icons.lock_outline;
  static const IconData unlock = Icons.lock_open_outlined;
  static const IconData scheduledLock = Icons.lock_clock_outlined;
  static const IconData protection = Icons.shield_outlined;
  static const IconData protectionGood = Icons.gpp_good_outlined;
  static const IconData protectionWeak = Icons.gpp_maybe_outlined;
  static const IconData protectionOff = Icons.gpp_bad_outlined;
  static const IconData verifiedUser = Icons.verified_user_outlined;
  static const IconData admin = Icons.admin_panel_settings_outlined;
  static const IconData web = Icons.travel_explore;
  static const IconData webAllowed = Icons.public;
  static const IconData webBlocked = Icons.public_off_rounded;
  static const IconData newApp = Icons.new_releases_outlined;
  static const IconData install = Icons.install_mobile_outlined;
  static const IconData touch = Icons.touch_app_outlined;
  static const IconData accessibility = Icons.accessibility_new_rounded;
  static const IconData raiseHand = Icons.front_hand_outlined;

  // Aparelho e vinculo.
  static const IconData device = Icons.smartphone_outlined;
  static const IconData devices = Icons.devices_other_outlined;
  static const IconData deviceRinging = Icons.phonelink_ring_outlined;
  static const IconData deviceLocked = Icons.phonelink_lock_outlined;
  static const IconData deviceSetup = Icons.phonelink_setup_outlined;
  static const IconData deviceUnlinked = Icons.phonelink_off_outlined;
  static const IconData battery = Icons.battery_std;
  static const IconData link = Icons.link;
  static const IconData unlink = Icons.link_off;
  static const IconData addLink = Icons.add_link;
  static const IconData qrCode = Icons.qr_code_2;
  static const IconData pinCode = Icons.pin_outlined;
  static const IconData phoneCall = Icons.phone_outlined;
  static const IconData emergency = Icons.emergency_outlined;

  // Conta e seguranca.
  static const IconData person = Icons.person_outline;
  static const IconData personAdd = Icons.person_add_alt_1_outlined;
  static const IconData family = Icons.family_restroom;
  static const IconData child = Icons.child_care_outlined;
  static const IconData guardian = Icons.admin_panel_settings_outlined;
  static const IconData group = Icons.groups_outlined;
  static const IconData email = Icons.alternate_email;
  static const IconData password = Icons.password;
  static const IconData key = Icons.key_outlined;
  static const IconData security = Icons.security;
  static const IconData privacy = Icons.privacy_tip_outlined;
  static const IconData settings = Icons.settings_outlined;
  static const IconData advanced = Icons.settings_suggest_outlined;

  // Notificacoes.
  static const IconData notification = Icons.notifications_outlined;
  static const IconData notificationActive = Icons.notifications_active_outlined;
  static const IconData notificationOff = Icons.notifications_off_outlined;
  static const IconData notificationNone = Icons.notifications_none;
  static const IconData chat = Icons.chat_bubble_outline;
  static const IconData approve = Icons.thumb_up_alt_outlined;

  // Relatorios e historico.
  static const IconData history = Icons.history;
  static const IconData timeline = Icons.timeline;
  static const IconData insights = Icons.insights_outlined;
  static const IconData list = Icons.list_alt_outlined;
  static const IconData table = Icons.table_rows_outlined;
  static const IconData audit = Icons.fact_check_outlined;
  static const IconData checklist = Icons.checklist_rounded;
  static const IconData layers = Icons.layers_outlined;

  // Categorias de apps.
  static const IconData categoryGames = Icons.sports_esports_outlined;
  static const IconData categoryEducation = Icons.school_outlined;
  static const IconData categoryVideo = Icons.smart_display_outlined;
  static const IconData categoryPhotos = Icons.photo_outlined;
  static const IconData categoryAudio = Icons.headphones_outlined;
  static const IconData categoryNews = Icons.newspaper_outlined;
  static const IconData categoryMaps = Icons.map_outlined;
  static const IconData categoryProductivity = Icons.work_outline;
  static const IconData categorySocial = Icons.groups_outlined;
  static const IconData categoryCommunication = Icons.chat_bubble_outline;
  static const IconData categoryOther = Icons.widgets_outlined;

  // Passos numerados.
  static const IconData stepOne = Icons.looks_one_outlined;
  static const IconData stepTwo = Icons.looks_two_outlined;
  static const IconData stepThree = Icons.looks_3_outlined;
}
