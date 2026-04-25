class ApiResponse {
  final String content;
  final bool isDelta;
  final bool done;

  const ApiResponse({
    required this.content,
    required this.isDelta,
    required this.done,
  });
}
