class ContactModel {
  final String id;
  final String name;
  final String phone;
  final String? avatar;

  ContactModel({
    required this.id,
    required this.name,
    required this.phone,
    this.avatar,
  });

  factory ContactModel.fromJson(
      String id,
      Map<String, dynamic> json,
      ) {
    return ContactModel(
      id: id,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      avatar: json['avatar'],
    );
  }
}