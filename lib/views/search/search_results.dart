import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:eatseasy/constants/constants.dart';
import 'package:eatseasy/controllers/search_controller.dart';
import 'package:eatseasy/models/foods.dart';
import 'package:eatseasy/views/food/widgets/food_tile.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

class SearchResults extends StatelessWidget {
  const SearchResults({super.key});

  @override
  Widget build(BuildContext context) {
    final searchController = Get.put(FoodSearchController());
    return Container(
      color: searchController.searchResults!.isEmpty|| searchController.searchResults == null ? kLightWhite : Colors.white,
      padding:  EdgeInsets.only(left: 12.w, top: 10.h, right: 12.w),
      height: hieght,
      child: searchController.searchResults!.isNotEmpty ? ListView.builder(
          scrollDirection: Axis.vertical,
          padding: EdgeInsets.zero,
          itemCount: searchController.searchResults!.length,
          itemBuilder: (context, index) {
             Food food = searchController.searchResults![index];
            return FoodTile(food: food);
          }): Padding(
            padding:  EdgeInsets.only(bottom:180.0.h),
            child: LottieBuilder.asset("assets/anime/delivery.json", width: width, height: hieght/2,),
          ),
    );
  }
}
