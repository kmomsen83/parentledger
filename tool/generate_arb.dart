// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Scans lib/ for Text('...') (no interpolation) and writes app_en.arb + app_es.arb.
/// Run from repo root: dart run tool/generate_arb.dart
void main() {
  final lib = Directory('lib');
  if (!lib.existsSync()) {
    stderr.writeln('Run from project root');
    exit(1);
  }

  final englishToKey = <String, String>{};

  // Preserve existing ARB strings so regenerated keys are not dropped after codemod.
  final existingArb = File('lib/l10n/app_en.arb');
  if (existingArb.existsSync()) {
    try {
      final prev =
          json.decode(existingArb.readAsStringSync()) as Map<String, dynamic>;
      for (final e in prev.entries) {
        if (e.key.startsWith('@') || e.key == '@@locale') continue;
        if (e.value is! String) continue;
        final v = e.value as String;
        if (v.contains('{')) continue;
        englishToKey.putIfAbsent(v, () => e.key);
      }
    } catch (_) {}
  }

  final textPat = RegExp(r"Text\(\s*'((?:\\.|[^'\\])*)'");

  for (final f in lib.listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    final content = f.readAsStringSync();
    for (final m in textPat.allMatches(content)) {
      var s = m.group(1)!;
      s = s.replaceAll(r"\'", "'");
      if (s.isEmpty || s.contains(r'$')) continue;
      if (s.contains('{')) continue;
      if (s.length < 2) continue;
      englishToKey.putIfAbsent(s, () => keyFromEnglish(s));
    }
  }

  // Stable product keys (override slug keys)
  const keyOverrides = <String, String>{
    'ParentLedger': 'appName',
    'Insights': 'insightsTitle',
    'CASE OVERVIEW': 'caseOverviewEyebrow',
    'Court Record Status': 'courtRecordStatusTitle',
    '+ Add Expense': 'addExpense',
    'Request reimbursement': 'requestReimbursement',
    'Case overview': 'caseOverview',
    'Messages': 'messages',
    'No messages yet': 'noMessages',
    'Start Free Trial': 'startFreeTrial',
    'Yearly': 'yearly',
    'Monthly': 'monthly',
    'Legal Record: Active': 'legalRecordActive',
    'Legal Record: Review recommended': 'legalRecordReviewRecommended',
    'Insights unavailable. Try again.': 'insightsUnavailable',
    'No insights available yet.': 'insightsNoDataYet',
    'Insights are being generated': 'insightsGenerating',
    'Welcome back, there': 'welcomeThere',
  };
  for (final e in keyOverrides.entries) {
    if (englishToKey.containsKey(e.key)) {
      englishToKey[e.key] = e.value;
    }
  }

  // Ensure unique key names + valid Dart identifiers (no reserved words).
  const reserved = <String>{
    'continue', 'break', 'class', 'void', 'if', 'else', 'for', 'while',
    'switch', 'case', 'default', 'return', 'new', 'this', 'null', 'true',
    'false', 'try', 'catch', 'finally', 'throw', 'assert', 'in', 'is', 'as',
    'super', 'extends', 'with', 'mixin', 'on', 'typedef', 'enum', 'import',
    'export', 'library', 'part', 'await', 'yield', 'async', 'sync',
  };
  String sanitizeKey(String k) {
    if (reserved.contains(k)) return '${k}Label';
    return k;
  }

  final used = <String>{};
  for (final s in englishToKey.keys.toList()) {
    var k = sanitizeKey(englishToKey[s]!);
    final base = k;
    var n = 2;
    while (used.contains(k)) {
      k = '$base$n';
      n++;
    }
    used.add(k);
    englishToKey[s] = k;
  }

  // Truncated split-string fragment from main.dart — use full body key instead.
  englishToKey.remove('Firebase failed to initialize on this build. ');

  // Required placeholders (not from scanner)
  final extraEn = <String, String>{
    'welcome': 'Welcome back, {name}',
    'appName': 'ParentLedger',
    'startupFailureBody':
        'Firebase failed to initialize on this build. Please verify Android Firebase config and restart the app.',
    'dashboardCaseSubtitle': 'Here\'s your case at a glance',
    'addExpense': '+ Add Expense',
    'addFirstExpense': 'Add First Expense',
    'requestReimbursement': 'Request reimbursement',
    'caseOverview': 'Case overview',
    'messages': 'Messages',
    'noMessages': 'No messages yet',
    'startFreeTrial': 'Start Free Trial',
    'yearly': 'Yearly',
    'monthly': 'Monthly',
    'legalRecordActive': 'Legal Record: Active',
    'legalRecordReviewRecommended': 'Legal Record: Review recommended',
    'insightsUnavailable': 'Insights unavailable. Try again.',
    'insightsNoDataYet': 'No insights available yet.',
    'insightsGenerating': 'Insights are being generated',
    'balanceRefreshing': 'Refreshing…',
    'balanceUpdatedJustNow': 'Updated just now',
    'balanceUpdatedMinutesAgo': 'Updated {minutes}m ago',
    'balanceUpdatedTodayIntro': 'Updated today ·',
    'completeWorkspaceSetupToTrackBalances':
        'Complete workspace setup to track balances.',
    'balanceUpdatedPrefix': 'Updated',
    'navHome': 'Home',
    'navInsights': 'Insights',
    'navTimeline': 'Timeline',
    'navExchange': 'Exchange',
    'navProfile': 'Profile',
    'expenseEvenPrefix': 'Even —',
    'youAreOwedPrefix': 'You are owed ',
    'youOwePrefix': 'You owe ',
  };

  final en = <String, dynamic>{
    '@@locale': 'en',
    ...{for (final e in englishToKey.entries) e.value: e.key},
    ...extraEn,
  };

  en['@welcome'] = {
    'description': 'Personalized dashboard greeting',
    'placeholders': {
      'name': {'type': 'String'},
    },
  };
  en['@balanceUpdatedMinutesAgo'] = {
    'placeholders': {
      'minutes': {'type': 'int'},
    },
  };

  final esStrings = spanishStrings();
  final es = <String, dynamic>{
    '@@locale': 'es',
    for (final e in englishToKey.entries)
      e.value: esStrings[e.key] ?? e.key,
    'welcome': 'Bienvenido de nuevo, {name}',
    'appName': 'ParentLedger',
  };
  es['@welcome'] = {
    'description': 'Saludo personalizado',
    'placeholders': {
      'name': {'type': 'String'},
    },
  };
  es['startupFailureBody'] =
      'Firebase no pudo iniciarse en esta compilación. Verifica la configuración de Firebase en Android y reinicia la app.';
  es['dashboardCaseSubtitle'] = 'Así va tu caso de un vistazo';
  es['addExpense'] = '+ Añadir gasto';
  es['addFirstExpense'] = 'Añadir primer gasto';
  es['requestReimbursement'] = 'Solicitar reembolso';
  es['caseOverview'] = 'Resumen del caso';
  es['messages'] = 'Mensajes';
  es['noMessages'] = 'Aún no hay mensajes';
  es['startFreeTrial'] = 'Prueba gratis';
  es['yearly'] = 'Anual';
  es['monthly'] = 'Mensual';
  es['legalRecordActive'] = 'Expediente legal: activo';
  es['legalRecordReviewRecommended'] =
      'Expediente legal: revisión recomendada';
  es['insightsUnavailable'] =
      'Perspectivas no disponibles. Inténtalo de nuevo.';
  es['insightsNoDataYet'] = 'Aún no hay perspectivas.';
  es['insightsGenerating'] = 'Generando perspectivas…';
  es['balanceRefreshing'] = 'Actualizando…';
  es['balanceUpdatedJustNow'] = 'Actualizado ahora';
  es['balanceUpdatedMinutesAgo'] = 'Actualizado hace {minutes} min';
  es['balanceUpdatedTodayIntro'] = 'Actualizado hoy ·';
  es['completeWorkspaceSetupToTrackBalances'] =
      'Completa la configuración del espacio de trabajo para ver saldos.';
  es['balanceUpdatedPrefix'] = 'Actualizado';
  es['navHome'] = 'Inicio';
  es['navInsights'] = 'Perspectivas';
  es['navTimeline'] = 'Cronología';
  es['navExchange'] = 'Intercambio';
  es['navProfile'] = 'Perfil';
  es['expenseEvenPrefix'] = 'En equilibrio —';
  es['youAreOwedPrefix'] = 'Te deben ';
  es['youOwePrefix'] = 'Debes ';
  es['@balanceUpdatedMinutesAgo'] = {
    'placeholders': {
      'minutes': {'type': 'int'},
    },
  };

  Directory('lib/l10n').createSync(recursive: true);
  File('lib/l10n/app_en.arb').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(en),
  );
  File('lib/l10n/app_es.arb').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(es),
  );

  print('Keys: ${englishToKey.length} scanned + ${extraEn.length} extra');
}

String keyFromEnglish(String s) {
  final slug = s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(5)
      .join('_');
  var base = slug.isEmpty ? 'message' : slug;
  final parts = base.split('_');
  final camel = parts.first +
      parts
          .skip(1)
          .map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')
          .join();
  var safe = camel.isEmpty ? 'message' : camel;
  safe = safe[0].toLowerCase() + safe.substring(1);
  if (RegExp(r'^[0-9]').hasMatch(safe) || safe == '82') {
    safe = 'msg$safe';
  }
  return safe;
}

Map<String, String> spanishStrings() {
  return {
    'Cancel': 'Cancelar',
    'Done': 'Listo',
    'Close': 'Cerrar',
    'Retry': 'Reintentar',
    'Back': 'Volver',
    'Continue': 'Continuar',
    'Save': 'Guardar',
    'Remove': 'Eliminar',
    'Insights': 'Perspectivas',
    'Messages': 'Mensajes',
    'Summary': 'Resumen',
    'Date': 'Fecha',
    'Time': 'Hora',
    'Location': 'Ubicación',
    'Export': 'Exportar',
    'Review': 'Revisar',
    'Help & Support': 'Ayuda y soporte',
    'Not now': 'Ahora no',
    'Start Free Trial': 'Prueba gratis',
    'Terms & Privacy': 'Términos y privacidad',
    'Not signed in': 'No has iniciado sesión',
    'Open maps': 'Abrir mapas',
    'Could not open maps': 'No se pudieron abrir los mapas',
    'Could not open maps on this device':
        'No se pudieron abrir los mapas en este dispositivo',
    'Navigate to exchange location?':
        '¿Abrir navegación al lugar del intercambio?',
    'No upcoming exchange location available':
        'No hay ubicación disponible para el próximo intercambio',
    'Link your case in workspace setup before logging expenses.':
        'Vincula tu caso en la configuración del espacio de trabajo antes de registrar gastos.',
    'View all threads': 'Ver todos los hilos',
    'Court Record Status': 'Estado del expediente judicial',
    'CASE OVERVIEW': 'RESUMEN DEL CASO',
    'Welcome to ParentLedger': 'Bienvenido a ParentLedger',
    'First 60 seconds': 'Primeros 60 segundos',
    'Start using dashboard': 'Empezar a usar el panel',
    'Shared expenses': 'Gastos compartidos',
    'Add First Expense': 'Añadir primer gasto',
    'Case documents': 'Documentos del caso',
    'Upload document': 'Subir documento',
    'Document uploaded': 'Documento subido',
    'Submit expense': 'Enviar gasto',
    'Expense submitted successfully.': 'Gasto enviado correctamente.',
    'No active case found.': 'No se encontró un caso activo.',
    'Approve expense': 'Aprobar gasto',
    'Deny expense': 'Rechazar gasto',
    'Expense not found.': 'Gasto no encontrado.',
    'Action Inbox': 'Bandeja de acciones',
    'Trust & Evidence': 'Confianza y pruebas',
    'Setup Progress': 'Progreso de configuración',
    'Case Timeline': 'Cronología del caso',
    'Case timeline': 'Cronología del caso',
    'Compliance Report': 'Informe de cumplimiento',
    'Compromise Center': 'Centro de acuerdos',
    'Custody Risk': 'Riesgo de custodia',
    'AI compliance scan': 'Análisis de cumplimiento con IA',
    'Try again': 'Intentar de nuevo',
    'Invite sent': 'Invitación enviada',
    'Send Invite': 'Enviar invitación',
    'Import from Contacts': 'Importar desde contactos',
    'Contacts permission is required to import.':
        'Se necesita permiso de contactos para importar.',
    'Schedule exchange': 'Programar intercambio',
    'Verify address': 'Verificar dirección',
    'Enter address manually': 'Introducir dirección manualmente',
    'Use address search': 'Usar búsqueda de dirección',
    'Exchange Scheduled': 'Intercambio programado',
    'View timeline': 'Ver cronología',
    'Navigate to location': 'Navegar a la ubicación',
    'Check-in recorded': 'Registro de llegada guardado',
    'Export record': 'Exportar registro',
    'Exchange check-in': 'Registro de llegada',
    'Log manual check-in': 'Registrar llegada manual',
    'No scheduled exchange': 'No hay intercambio programado',
    'Upcoming exchange': 'Próximo intercambio',
    'Review details': 'Revisar detalles',
    'Detecting your location…': 'Detectando tu ubicación…',
    'Refresh location': 'Actualizar ubicación',
    'Open navigation': 'Abrir navegación',
    'Start check-in': 'Iniciar registro',
    'Manual check-in': 'Registro manual',
    'Capturing GPS…': 'Capturando GPS…',
    'Active check-in': 'Registro activo',
    'Live time': 'Hora en vivo',
    'GPS coordinates': 'Coordenadas GPS',
    'Refresh GPS': 'Actualizar GPS',
    'Complete check-in': 'Completar registro',
    'Could not send message. Try again.':
        'No se pudo enviar el mensaje. Inténtalo de nuevo.',
    'Mark important': 'Marcar como importante',
    'Highlight for review and exports':
        'Destacar para revisión y exportaciones',
    'Mark as evidence': 'Marcar como prueba',
    'Flag for disclosure bundles': 'Marcar para paquetes de divulgación',
    'Export PDF (full thread)': 'Exportar PDF (hilo completo)',
    'Export PDF (last 30 days)': 'Exportar PDF (últimos 30 días)',
    'Export PDF (flagged / risk only)':
        'Exportar PDF (solo marcados / riesgo)',
    'Save extended record to case': 'Guardar registro ampliado en el caso',
    'Send as written': 'Enviar tal como está',
    'Use AI suggestion': 'Usar sugerencia de IA',
    'Generating attorney brief…': 'Generando informe para abogado…',
    'Attorney brief saved to legal summaries.':
        'Informe guardado en resúmenes legales.',
    'Saving extended case summary…': 'Guardando resumen ampliado del caso…',
    'Summary saved to your case legal records.':
        'Resumen guardado en los registros legales del caso.',
    'Add a few more messages before generating a summary.':
        'Añade más mensajes antes de generar un resumen.',
    'Copied to clipboard': 'Copiado al portapapeles',
    'PDF export coming soon': 'Exportación PDF próximamente',
    'Total (range)': 'Total (rango)',
    'Outstanding': 'Pendiente',
    'Continue with limited access': 'Continuar con acceso limitado',
    'Mark unpaid': 'Marcar como no pagado',
    'Could not save. Please try again.':
        'No se pudo guardar. Inténtalo de nuevo.',
    'Document type': 'Tipo de documento',
    'Child added successfully': 'Niño añadido correctamente',
    'Remove child?': '¿Eliminar niño?',
    'Add child': 'Añadir niño',
    'Profile photo updated': 'Foto de perfil actualizada',
    'Upload failed': 'Error al subir',
    'Could not open subscription settings':
        'No se pudo abrir la configuración de suscripción',
    'Invite cancelled': 'Invitación cancelada',
    'Cancel invite': 'Cancelar invitación',
    'Resend': 'Reenviar',
    'Manage Plan': 'Gestionar plan',
    'Cancel Subscription': 'Cancelar suscripción',
    'Take Photo': 'Hacer foto',
    'Choose from Gallery': 'Elegir de la galería',
    'Invite saved — invite link is ready.':
        'Invitación guardada: el enlace está listo.',
    'Go back': 'Volver',
    'Skip': 'Omitir',
    'Review expense': 'Revisar gasto',
    'Mark as already paid': 'Marcar como ya pagado',
    'Turn off if reimbursement is pending.':
        'Desactiva si el reembolso está pendiente.',
    'Back to sign in': 'Volver al inicio de sesión',
    'Mother': 'Madre',
    'Father': 'Padre',
    'Guardian': 'Tutor',
    'Could not continue. Please try again.':
        'No se pudo continuar. Inténtalo de nuevo.',
    'Address verified for this exchange.':
        'Dirección verificada para este intercambio.',
    'Case not ready — finish workspace setup':
        'El caso no está listo: termina la configuración del espacio de trabajo',
    'Add a child to your case before scheduling.':
        'Añade un niño al caso antes de programar.',
    'Complete all sections, including a verified location.':
        'Completa todas las secciones, incluida una ubicación verificada.',
    "We're here to help": 'Estamos aquí para ayudarte',
    'We’re here to help': 'Estamos aquí para ayudarte',
    'Could not open email app': 'No se pudo abrir la app de correo',
    'FAQs': 'Preguntas frecuentes',
    'AI chat support is on the roadmap':
        'El chat de soporte con IA está en la hoja de ruta',
    'Invite attorney': 'Invitar a abogado',
    'Generate invite link': 'Generar enlace de invitación',
    'Invite ID': 'ID de invitación',
    'Invite ID copied': 'ID de invitación copiado',
    'Copy invite ID': 'Copiar ID de invitación',
    'Timestamp': 'Marca de tiempo',
    'Address': 'Dirección',
    'View Pro plans': 'Ver planes Pro',
    'AI Fairness Analysis': 'Análisis de equidad con IA',
    'Parenting Time Distribution': 'Distribución del tiempo parental',
    'AI Reasoning': 'Razonamiento de la IA',
    'Suggested Compromise': 'Acuerdo sugerido',
    'Counter suggestion flow opens from proposals.':
        'El flujo de contraoferta se abre desde propuestas.',
    'Counter Suggestion': 'Contraoferta',
    'AI compromise saved to review flow.':
        'Acuerdo de IA guardado en el flujo de revisión.',
    'Accept AI Proposal': 'Aceptar propuesta de IA',
    'Overall Compliance': 'Cumplimiento general',
    'Last 30 days': 'Últimos 30 días',
    'Flagged Events': 'Eventos marcados',
    'Open Timeline': 'Abrir cronología',
    'Compromise Health': 'Salud de los acuerdos',
    'Active Negotiations': 'Negociaciones activas',
    'Setup progress': 'Progreso de configuración',
    'Current step': 'Paso actual',
    'Not signed in. Please sign in again.':
        'No hay sesión. Vuelve a iniciar sesión.',
    'Attorney': 'Abogado',
    'Judge': 'Juez',
    'Startup connection issue': 'Problema de conexión al iniciar',
    'No AI suggestion available for this message.':
        'No hay sugerencia de IA para este mensaje.',
    '+ Add Expense': '+ Añadir gasto',
    'Request reimbursement': 'Solicitar reembolso',
    'Case overview': 'Resumen del caso',
    'No messages yet': 'Aún no hay mensajes',
    'Yearly': 'Anual',
    'Monthly': 'Mensual',
    'Legal Record: Active': 'Expediente legal: activo',
    'Legal Record: Review recommended':
        'Expediente legal: revisión recomendada',
    'Insights unavailable. Try again.':
        'Perspectivas no disponibles. Inténtalo de nuevo.',
    'No insights available yet.': 'Aún no hay perspectivas.',
    'Insights are being generated': 'Generando perspectivas…',
    'ParentLedger': 'ParentLedger',
    'Balance': 'Saldo',
    'Calculating…': 'Calculando…',
    'Even — ': 'En equilibrio — ',
    'You are owed ': 'Te deben ',
    'You owe ': 'Debes ',
    'Refreshing…': 'Actualizando…',
    'Updated just now': 'Actualizado ahora',
    'Complete workspace setup to track balances.':
        'Completa la configuración del espacio de trabajo para ver saldos.',
    '—': '—',
    '• ': '• ',
  };
}
