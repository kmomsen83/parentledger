import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../models/child_model.dart';
import '../providers/case_context.dart';
import '../services/child_service.dart';
import 'child_profile_screen.dart';

/// Lists children on the case with navigation to full profiles (production).
class EliteChildrenDirectoryScreen extends StatelessWidget {
  const EliteChildrenDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final caseId = context.watch<CaseContext>().caseId;

    return Scaffold(
      backgroundColor: PLDesign.background,
      body: Container(
        decoration: PLDesign.screenGradient,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
                    ),
                    const Expanded(
                      child: Text(
                        'Children',
                        style: PLDesign.pageTitle,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: caseId == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Text(
                            'Link your workspace to see children on this case.',
                            textAlign: TextAlign.center,
                            style: PLDesign.body,
                          ),
                        ),
                      )
                    : StreamBuilder<List<ChildModel>>(
                        stream: ChildService.watchChildren(caseId),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return Center(
                              child: Text(
                                'Could not load children.',
                                style: PLDesign.body,
                              ),
                            );
                          }
                          if (!snap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(color: PLDesign.primary),
                            );
                          }
                          final kids = snap.data!;
                          if (kids.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Text(
                                  'No children added yet. Add a child from your profile / onboarding.',
                                  textAlign: TextAlign.center,
                                  style: PLDesign.body,
                                ),
                              ),
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
                            itemCount: kids.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final c = kids[i];
                              final model = ChildModel(
                                id: c.id,
                                name: c.name,
                                dob: c.dob,
                                gender: c.gender,
                                school: c.school,
                                grade: c.grade,
                                activities: c.activities,
                                medicalNotes: c.medicalNotes,
                                photoUrl: c.photoUrl,
                                createdAt: c.createdAt,
                                caseId: caseId,
                              );
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push<void>(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) => ChildProfileScreen(child: model),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(18),
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      color: PLDesign.card,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: PLDesign.border),
                                      boxShadow: PLDesign.softShadow,
                                    ),
                                    padding: const EdgeInsets.all(18),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 26,
                                          backgroundColor: PLDesign.surface,
                                          backgroundImage: model.photoUrl != null &&
                                                  model.photoUrl!.isNotEmpty
                                              ? NetworkImage(model.photoUrl!)
                                              : null,
                                          child: model.photoUrl == null || model.photoUrl!.isEmpty
                                              ? Text(
                                                  model.initials,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                model.name,
                                                style: PLDesign.sectionTitle,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                model.displayAge.isEmpty
                                                    ? model.gender
                                                    : '${model.displayAge} · ${model.gender}',
                                                style: PLDesign.caption,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right, color: Colors.white54),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
