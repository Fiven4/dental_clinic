class ListPermissions {
  final bool create;
  final bool edit;
  final bool delete;
  final bool restore;
  final bool hardDelete;

  const ListPermissions({
    this.create = false,
    this.edit = false,
    this.delete = false,
    this.restore = false,
    this.hardDelete = false,
  });

  static const readOnly = ListPermissions();
  static const all = ListPermissions(
    create: true,
    edit: true,
    delete: true,
    restore: true,
    hardDelete: true,
  );
}
