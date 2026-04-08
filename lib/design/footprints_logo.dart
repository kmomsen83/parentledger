import 'package:flutter/material.dart';

class FootprintsLogo extends StatelessWidget {
final double size;

const FootprintsLogo({
super.key,
this.size = 28,
});

@override
Widget build(BuildContext context) {
return SizedBox(
width: size * 1.4,
height: size,
child: Stack(
children: [

/// BACK FOOT
Positioned(
left: 0,
bottom: 0,
child: Transform.rotate(
angle: -.35,
child: _Foot(
size: size * .9,
),
),
),

/// FRONT FOOT
Positioned(
right: 0,
top: 0,
child: Transform.rotate(
angle: .35,
child: _Foot(
size: size,
),
),
),
],
),
);
}
}

class _Foot extends StatelessWidget {
final double size;

const _Foot({required this.size});

@override
Widget build(BuildContext context) {
return SizedBox(
width: size * .6,
height: size,
child: Stack(
alignment: Alignment.bottomCenter,
children: [

/// HEEL
Container(
width: size * .5,
height: size * .75,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(100),
gradient: const LinearGradient(
begin: Alignment.topLeft,
end: Alignment.bottomRight,
colors: [
Color(0xffA7DBFF),
Color(0xff3D7CFF),
],
),
),
),

/// TOES ROW
Positioned(
top: 0,
child: Row(
mainAxisSize: MainAxisSize.min,
children: List.generate(
5,
(i) => Container(
margin: EdgeInsets.only(
right: i == 4 ? 0 : size * .04,
),
width: size * (.12 + (i * .01)),
height: size * (.12 + (i * .01)),
decoration: const BoxDecoration(
shape: BoxShape.circle,
gradient: LinearGradient(
colors: [
Color(0xffA7DBFF),
Color(0xff3D7CFF),
],
),
),
),
),
),
),
],
),
);
}
}
