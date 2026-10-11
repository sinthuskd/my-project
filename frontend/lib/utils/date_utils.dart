const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _mo = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String weekdayShort(DateTime d) => _wd[d.weekday - 1];
String monthShort(DateTime d) => _mo[d.month - 1];
String dayMonth(DateTime d) => '${monthShort(d)} ${d.day}';
String fullDate(DateTime d) =>
    '${weekdayShort(d)}, ${d.day.toString().padLeft(2, '0')} ${monthShort(d)} ${d.year}';
