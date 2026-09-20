enum RecordSource {
  staff,
  catalog;

  static RecordSource fromStorage(String? value) {
    if (value == catalog.name) return catalog;
    return staff;
  }
}
