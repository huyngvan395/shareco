import 'package:flutter/cupertino.dart';

class ProductListScreen extends StatefulWidget{
  const ProductListScreen({super.key});

  @override
  State<StatefulWidget> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen>{
  @override
  Widget build(BuildContext context) {
    return Text("Product List Screen");
  }

}