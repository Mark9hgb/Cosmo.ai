import 'package:equatable/equatable.dart';

class ApiResponse extends Equatable {
  final String content;
  final bool isDelta;
  final bool done;
  final String? model;

  const ApiResponse({
    required this.content,
    this.isDelta = false,
    this.done = false,
    this.model,
  });

  @override
  List<Object?> get props => [content, isDelta, done, model];
}