import 'package:flutter/material.dart';

class CreateVideoScreen extends StatefulWidget{
  const CreateVideoScreen({super.key});

  @override
  State<StatefulWidget> createState() => _CreateVideoScreenState();
}

class _CreateVideoScreenState extends State<CreateVideoScreen>{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Create Video"),
        centerTitle: true,
      ),
      body: Text("Create Video Screen")
    );
  }

}