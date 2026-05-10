Future<String> _generateAIPlan() async {
  await Future.delayed(const Duration(seconds: 1));

  return "💡 Suggested Plan:\n\n"
      "- Reduce food spending by 15%\n"
      "- Limit shopping to 2 times/week\n"
      "- Save at least \$200 this month\n"
      "- Avoid unnecessary subscriptions";
}