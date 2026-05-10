class UserModel {
  final String name;
  final String email;
  final String username;
  final String phone;
  final String image;

  UserModel({
    required this.name,
    required this.email,
    required this.username,
    required this.phone,
    required this.image,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      phone: data['phone'] ?? '',
      image: data['image'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'username': username,
      'phone': phone,
      'image': image,
    };
  }
}