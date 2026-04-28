import 'package:flutter/cupertino.dart';

class ChatScreen extends StatefulWidget{
  const ChatScreen({super.key});

  @override
  State<StatefulWidget> createState() => _ChatScreenState();

}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return Text("Chat Screen");
  }

}