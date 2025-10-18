import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';

ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAwesomeSnackBar(
  BuildContext context, {
  required String title,
  required String message,
  required ContentType contentType,
  Duration duration = const Duration(seconds: 4),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  final snackBar = SnackBar(
    elevation: 0,
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    duration: duration,
    content: AwesomeSnackbarContent(
      title: title,
      message: message,
      contentType: contentType,
    ),
  );

  return messenger.showSnackBar(snackBar);
}

Future<void> showSuccessDialog(
  BuildContext context, {
  String title = "สำเร็จ",
  String message = "ดำเนินการสำเร็จ",
  Duration duration = const Duration(seconds: 4),
  VoidCallback? onOk,
}) async {
  final controller = showAwesomeSnackBar(
    context,
    title: title,
    message: message,
    contentType: ContentType.success,
    duration: duration,
  );

  await controller.closed;
  onOk?.call();
}

Future<void> showErrorDialog(
  BuildContext context, {
  String title = "ไม่สำเร็จ",
  String message = "ดำเนินการไม่สำเร็จ",
  Duration duration = const Duration(seconds: 4),
  VoidCallback? onAction,
}) async {
  final controller = showAwesomeSnackBar(
    context,
    title: title,
    message: message,
    contentType: ContentType.failure,
    duration: duration,
  );

  await controller.closed;
  onAction?.call();
}

Future<void> showWarningSnackBar(
  BuildContext context, {
  required String title,
  required String message,
  Duration duration = const Duration(seconds: 4),
  VoidCallback? onClosed,
}) async {
  final controller = showAwesomeSnackBar(
    context,
    title: title,
    message: message,
    contentType: ContentType.warning,
    duration: duration,
  );

  await controller.closed;
  onClosed?.call();
}

Future<void> showInfoSnackBar(
  BuildContext context, {
  required String title,
  required String message,
  Duration duration = const Duration(seconds: 4),
  VoidCallback? onClosed,
}) async {
  final controller = showAwesomeSnackBar(
    context,
    title: title,
    message: message,
    contentType: ContentType.help,
    duration: duration,
  );

  await controller.closed;
  onClosed?.call();
}
