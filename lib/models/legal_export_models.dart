class ExportDocument {
final String title;
final DateTime generatedAt;
final String caseId;
final List<ExportSection> sections;

ExportDocument({
required this.title,
required this.generatedAt,
required this.caseId,
required this.sections,
});
}

class ExportSection {
final String header;
final List<ExportEntry> entries;

ExportSection({
required this.header,
required this.entries,
});
}

class ExportEntry {
final DateTime timestamp;
final String title;
final String description;
final String? metadata;

ExportEntry({
required this.timestamp,
required this.title,
required this.description,
this.metadata,
});
}
