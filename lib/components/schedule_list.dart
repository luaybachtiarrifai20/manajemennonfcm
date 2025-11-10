import 'package:flutter/material.dart';
import 'schedule_card.dart';

class ScheduleList extends StatelessWidget {
  final List<dynamic> schedules;
  final Function(dynamic) onEditSchedule;
  final Function(String) onDeleteSchedule;

  const ScheduleList({
    super.key,
    required this.schedules,
    required this.onEditSchedule,
    required this.onDeleteSchedule,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: schedules.length,
      itemBuilder: (context, index) {
        final schedule = schedules[index];
        return ScheduleCard(
          schedule: schedule,
          onEdit: () => onEditSchedule(schedule),
          onDelete: () => onDeleteSchedule(schedule['id']),
        );
      },
    );
  }
}