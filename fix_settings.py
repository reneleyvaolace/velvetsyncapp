with open('lib/widgets/settings_system_card.dart', 'r') as f:
    lines = f.readlines()

# Remove the import
new_lines = []
for line in lines:
    if "import 'package:velvet_sync/screens/backup_screen.dart';" not in line:
        new_lines.append(line)

# Comment out the _CloudBackupOption class
in_class = False
class_start = -1
brace_count = 0
for i, line in enumerate(new_lines):
    if 'class _CloudBackupOption extends StatelessWidget' in line and not in_class:
        class_start = i
        in_class = True
        brace_count = 0
    if in_class:
        brace_count += line.count('{') - line.count('}')
        if brace_count == 0 and class_start != -1 and i > class_start:
            class_end = i
            for j in range(class_start, class_end + 1):
                new_lines[j] = '// ' + new_lines[j]
            break

with open('lib/widgets/settings_system_card.dart', 'w') as f:
    f.writelines(new_lines)
print('Done')