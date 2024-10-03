class Department {
  final String name;
  final List<String> members;

  Department({required this.name, required this.members});

  // Static method to get a list of departments with members
  static List<Department> getDepartments() {
    return [
      Department(
        name: 'Support',
        members: ['user 1', 'user 2', 'user 3'],
      ),
      Department(
        name: 'Development',
        members: ['Vaibhav', 'Praveen', 'Ashi'],
      ),
      Department(
        name: 'Sales',
        members: ['Sales 1', 'Sales 2'],
      ),
      // Add more departments as needed
    ];
  }
}
