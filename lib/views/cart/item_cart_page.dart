import 'package:eatseasy/models/restaurants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:eatseasy/common/app_style.dart';
import 'package:eatseasy/common/custom_container.dart';
import 'package:eatseasy/common/reusable_text.dart';
import 'package:eatseasy/common/shimmers/foodlist_shimmer.dart';
import 'package:eatseasy/constants/constants.dart';
import 'package:eatseasy/hooks/fetchCart.dart';
import 'package:eatseasy/models/user_cart.dart';
import 'package:eatseasy/views/auth/widgets/login_redirect.dart';
import 'package:eatseasy/views/cart/widgets/cart_tile.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../common/divida.dart';
import '../../controllers/address_controller.dart';
import '../../controllers/location_controller.dart';
import '../../controllers/order_controller.dart';
import '../../models/distance_time.dart';
import '../../models/order_item.dart';
import '../../services/distance.dart';
import '../home/widgets/custom_btn.dart';
import '../orders/payment.dart';
import '../profile/saved_places.dart';
import '../profile/add_new_place.dart';
import '../restaurant/restaurants_page.dart'; // Import for using min function

class ItemCartPage extends HookWidget {
  const ItemCartPage({super.key, required this.restaurant});
  final Restaurants restaurant;

  @override
  Widget build(BuildContext context) {
    final TextEditingController phone = TextEditingController();
    final controller = Get.put(AddressController());
    final orderController = Get.put(OrderController());
    final location = Get.put(UserLocationController());
    late GoogleMapController mapController;
    final box = GetStorage();
    String? token = box.read('token');

    final hookResult = useFetchCart();
    final items = hookResult.data ?? [];
    final isLoading = hookResult.isLoading;

    // Reset matchingCarts on each build
    List<OrderItem> matchingCarts = [];
    List<String> foodTimeList = [];

    void onMapCreated(GoogleMapController controller) {
      mapController = controller;
    }

    LatLng me = LatLng(
      controller.defaultAddress!.latitude,
      controller.defaultAddress!.longitude,);

    final selectedDeliveryOption = useState<String>('Standard');
    String deliveryOption = selectedDeliveryOption.value;

    final selectedPaymentMethod = useState<String>('STRIPE');
    String paymentMethod = selectedPaymentMethod.value;

    final distanceTime = useState<DistanceTime?>(null);
    final standardDeliveryTime = useState<double>(0); // Initialize with base time
    final totalDeliveryOptionTime = useState<double>(0);
    final orderSubTotal = useState<num>(0);
    final totalDeliveryOptionPrice = useState<double>(0);
    final standardDeliveryPrice = useState<double>(0);
    final total = useState<double>(0);

    Future<void> selectDeliveryOption(String selectedDeliveryOption) async {
      if (selectedDeliveryOption == 'Priority') {
        totalDeliveryOptionTime.value = standardDeliveryTime.value - 10; // Priority reduces 10 mins
        totalDeliveryOptionPrice.value = standardDeliveryPrice.value + 20;
        total.value = orderSubTotal.value.toDouble() + totalDeliveryOptionPrice.value;
      } else if (selectedDeliveryOption == 'Saver') {
        totalDeliveryOptionTime.value = standardDeliveryTime.value + 15; // Saver adds 15 mins
        totalDeliveryOptionPrice.value = standardDeliveryPrice.value - 10;
        total.value = orderSubTotal.value.toDouble() + totalDeliveryOptionPrice.value;
      } else if (selectedDeliveryOption == 'Standard') {
        totalDeliveryOptionTime.value = standardDeliveryTime.value; // Standard, no change
        totalDeliveryOptionPrice.value = standardDeliveryPrice.value;
        total.value = orderSubTotal.value.toDouble() + totalDeliveryOptionPrice.value;
      }
    }

    Future<void> fetchDistance() async {
      Distance distanceCalculator = Distance();
      distanceTime.value = await distanceCalculator.calculateDistanceDurationPrice(
        controller.defaultAddress!.latitude,
        controller.defaultAddress!.longitude,
        restaurant.coords.latitude,
        restaurant.coords.longitude,
        35,
        pricePkm,
      );
    }

    /*LatLng _center = const LatLng(37.78792117665919, -122.41325651079953);
    Future<void> getCurrentLocation() async {
      location.setUserLocation(_center);
      var currentLocation = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      _center = LatLng(currentLocation.latitude, currentLocation.longitude);
      location.getAddressFromLatLng(_center);

    }*/

    useEffect(() {
      num orderTotalAmount = 0;

      fetchDistance().then((_) {
        if (distanceTime.value != null) {
          standardDeliveryTime.value += distanceTime.value!.time;
          for (var cart in items) {
            if (cart.restaurant == restaurant.id) {
              orderTotalAmount += cart.totalPrice;
              foodTimeList.add(cart.prepTime);
            }
          }
          List<int> intList = foodTimeList.map(int.parse).toList();
          int highestNumber = (intList.length == 1)
              ? intList.first
              : intList.reduce((current, next) => current > next ? current : next);
          standardDeliveryTime.value += highestNumber.toDouble();
          totalDeliveryOptionTime.value = standardDeliveryTime.value;
          print("Highest prep time: " + highestNumber.toString());

          orderSubTotal.value = orderTotalAmount; // Update state with new total
          standardDeliveryPrice.value = distanceTime.value!.price;
          totalDeliveryOptionPrice.value = standardDeliveryPrice.value;
          total.value = orderSubTotal.value.toDouble() + totalDeliveryOptionPrice.value;
        } else {
          // Handle null distanceTime, e.g., set a default value
          orderSubTotal.value = orderTotalAmount;
          total.value = orderSubTotal.value.toDouble(); // Assuming no additional price
        }
      });

      return null; // Effect cleanup not needed
    }, [items]);

    return token == null
        ? const LoginRedirection()
        : Obx(() => orderController.paymentUrl.contains("https")
        ? const PaymentWebView()
        : Scaffold(
      appBar: AppBar(
        backgroundColor: kLightWhite,
        elevation: 0.3,
        centerTitle: true,
        title: ReusableText(
          text: "Cart",
          style: appStyle(20, kDark, FontWeight.w400),
        ),
      ),
      body:isLoading ? const FoodsListShimmer()
          :SafeArea(
        child: CustomContainer(
          containerContent: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                color: kLightWhite,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  width: width,
                  decoration: const BoxDecoration(
                      color: kOffWhite,
                      borderRadius: BorderRadius.all(Radius.circular(9))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Address Section
                      Row(
                        children: [
                          const Icon(
                            Entypo.location_pin,
                            color: kDark,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          ReusableText(
                              text: "Delivery Address",
                              style: appStyle(20, kDark, FontWeight.w400)),
                        ],
                      ),

                      Container(
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                          child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                              width: width,
                              decoration: const BoxDecoration(
                                  color: kWhite,
                                  borderRadius: BorderRadius.all(Radius.circular(9))),
                              child: Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      height: 150,
                                      child: GoogleMap(
                                        onMapCreated: onMapCreated,
                                        initialCameraPosition: CameraPosition(
                                          target: me,
                                          zoom: 16,
                                        ),
                                        markers: {
                                          Marker(
                                            markerId: const MarkerId('Me'),
                                            draggable: true,
                                            position: me,
                                          ),
                                        },
                                      ),
                                    ),
                                  ),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(controller.userAddress ?? "Provide an address to proceed ordering",
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold, fontSize: 16)),
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Get.to(() => SavedPlaces());
                                        },
                                        child: const Text('Edit'),
                                      ),
                                    ],
                                  ),
                                ],)
                          )
                      ),

                      // Delivery Options Section
                      ReusableText(
                          text: "Delivery options",
                          style: appStyle(20, kDark, FontWeight.w400)),
                      const SizedBox(height: 8),
                      ReusableText(
                          text: "Distance from you: ${distanceTime.value != null
                              ? "${distanceTime.value!.distance.toStringAsFixed(2)} km"
                              : "Loading..."}",
                          style: appStyle(11, kDark, FontWeight.w400)),
                      const SizedBox(height: 8),

                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          decoration: const BoxDecoration(
                              color: kWhite,
                              borderRadius: BorderRadius.all(Radius.circular(9))),
                          child: // Priority Option
                          RadioListTile(
                            activeColor: kPrimary,
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [

                                Text('Priority < ${standardDeliveryTime.value.toStringAsFixed(0)} mins'),
                                Text('₱${(standardDeliveryPrice.value + 20).toStringAsFixed(2)}'),
                              ],
                            ),
                            subtitle: const Text('Shortest waiting time to get your order.'),
                            value: 'Priority',
                            groupValue: selectedDeliveryOption.value,
                            onChanged: (value) {
                              selectDeliveryOption(value!);
                              selectedDeliveryOption.value = value;
                            },
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          width: width,
                          decoration: const BoxDecoration(
                              color: kWhite,
                              borderRadius: BorderRadius.all(Radius.circular(9))),
                          child: // Priority Option
                          // Standard Option
                          RadioListTile(
                            activeColor: kPrimary,
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Standard • ${standardDeliveryTime.value.toStringAsFixed(0)} mins'),
                                Text('₱${standardDeliveryPrice.value.toStringAsFixed(2)}'),
                              ],
                            ),
                            value: 'Standard',
                            groupValue: selectedDeliveryOption.value,
                            onChanged: (value) {
                              selectDeliveryOption(value!);
                              selectedDeliveryOption.value = value;
                            },
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          width: width,
                          decoration: const BoxDecoration(
                              color: kWhite,
                              borderRadius: BorderRadius.all(Radius.circular(9))),
                          child: // Priority Option
                          // Standard Option
                          RadioListTile(
                            activeColor: kPrimary,
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Saver • ${(standardDeliveryTime.value + 15).toStringAsFixed(0)} mins'),
                                Text('₱${(standardDeliveryPrice.value - 10).toStringAsFixed(2)}'),
                              ],
                            ),
                            value: 'Saver',
                            groupValue: selectedDeliveryOption.value,
                            onChanged: (value) {
                              selectDeliveryOption(value!);
                              selectedDeliveryOption.value = value;
                            },
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          width: width,
                          decoration: const BoxDecoration(
                              color: kWhite,
                              borderRadius: BorderRadius.all(Radius.circular(9))),
                          child: // Priority Option
                          // Standard Option
                          RadioListTile(
                            activeColor: kPrimary,
                            title: const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Order for later'),
                              ],
                            ),
                            value: 'Later',
                            groupValue: selectedDeliveryOption.value,
                            onChanged: (value) {
                              selectDeliveryOption(value!);
                              selectedDeliveryOption.value = value;
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                color: kLightWhite,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  width: width,
                  decoration: const BoxDecoration(
                    color: kOffWhite,
                    borderRadius: BorderRadius.all(Radius.circular(9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Entypo.list,
                            color: kDark,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          ReusableText(
                            text: "Order summary",
                            style: appStyle(20, kDark, FontWeight.w400),
                          ),
                        ],
                      ),

                      isLoading
                          ? const FoodsListShimmer()
                          : Container(
                        decoration: const BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(9))),
                        child: ListView.builder(
                          shrinkWrap: true, // Adjust height based on content
                          physics: const NeverScrollableScrollPhysics(), // Disable scrolling to avoid nested scroll issues
                          padding: EdgeInsets.zero, // Remove unnecessary padding
                          itemCount: items.length,
                          itemBuilder: (context, i) {
                            UserCart cart = items[i];

                            if (cart.restaurant == restaurant.id) {
                              OrderItem orderItem = OrderItem(
                                foodId: cart.productId.id,
                                additives: cart.additives,
                                quantity: cart.quantity.toString(),
                                price: cart.totalPrice.toStringAsFixed(2),
                                instructions: cart.instructions,
                                cartItemId: cart.id,
                              );

                              matchingCarts.add(orderItem);

                              return CartTile(item: cart);
                            } else {
                              return Container();
                            }
                          },
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RowText(
                            first: "Estimated delivery time",
                            second: distanceTime.value != null
                                ? "${"${totalDeliveryOptionTime.value.toStringAsFixed(0)} - ${(totalDeliveryOptionTime.value + distanceTime.value!.time).toStringAsFixed(0)}" } mins."
                                : "Loading...",
                          ),
                          RowText(
                            first: "Delivery fee",
                            second: distanceTime.value != null
                                ? "\$ ${totalDeliveryOptionPrice.value.toStringAsFixed(2)}"
                                : "Loading...",
                          ),
                          SizedBox(height: 5.h),
                          RowText(
                            first: "Subtotal",
                            second: distanceTime.value != null
                                ? "\$ ${orderSubTotal.value.toStringAsFixed(2)}"
                                : "Loading...",
                          ),
                          const Divida(),
                          SizedBox(height: 5.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Total: ",
                                style: TextStyle(
                                  color: kDark,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Row(
                                children: [
                                  isLoading
                                      ? Container()
                                      : Padding(
                                    padding: const EdgeInsets.all(0),
                                    child: Text(
                                      total.value % 1 == 0
                                          ? " \$${total.value.toStringAsFixed(0)}"
                                          : " \$${total.value.toStringAsFixed(2)}",
                                      style: const TextStyle(
                                        color: kDark,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Rest of your widgets
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                color: kLightWhite,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  width: width,
                  decoration: const BoxDecoration(
                    color: kOffWhite,
                    borderRadius: BorderRadius.all(Radius.circular(9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Entypo.wallet,
                            color: kDark,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          ReusableText(
                            text: "Payment method",
                            style: appStyle(20, kDark, FontWeight.w400),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          width: width,
                          decoration: const BoxDecoration(
                              color: kWhite,
                              borderRadius: BorderRadius.all(Radius.circular(9))),
                          child: // Priority Option
                          // Standard Option
                          RadioListTile(
                            activeColor: kPrimary,
                            title: const Row(
                              children: [
                                Icon(
                                  Entypo.wallet,
                                  color: kDark,
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Text('Stripe'),
                              ],
                            ),
                            value: 'STRIPE',
                            groupValue: selectedPaymentMethod.value,
                            onChanged: (value) {
                              selectDeliveryOption(value!);
                              selectedPaymentMethod.value = value;
                            },
                          ),
                        ),
                      ),

                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          width: width,
                          decoration: const BoxDecoration(
                              color: kWhite,
                              borderRadius: BorderRadius.all(Radius.circular(9))),
                          child: // Priority Option
                          // Standard Option
                          RadioListTile(
                            activeColor: kPrimary,
                            title: const Row(
                              children: [
                                Icon(
                                  Icons.money_rounded,
                                  color: kDark,
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Text('Cash on delivery'),
                              ],
                            ),
                            value: 'COD',
                            groupValue: selectedPaymentMethod.value,
                            onChanged: (value) {
                              selectDeliveryOption(value!);
                              selectedPaymentMethod.value = value;
                            },
                          ),
                        ),
                      ),

                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), // Adjust the radius value as needed
        child: BottomAppBar(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          shape: const CircularNotchedRectangle(),
          height: height * 0.2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {},
                child: RowText(
                  first: "Phone ",
                  second: phone.text.isEmpty
                      ? "Tap to add a phone number before ordering"
                      : phone.text,
                ),
              ),
              SizedBox(height: 5.h),
              const Divida(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Total: ",
                    style: TextStyle(
                      color: kDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      isLoading
                          ? Center(
                        child: LoadingAnimationWidget.threeArchedCircle(
                          color: kPrimary,
                          size: width - 390,
                        ),
                      )
                          : Padding(
                        padding: const EdgeInsets.all(0),
                        child: Text(
                          total.value % 1 == 0
                              ? " \$${total.value.toStringAsFixed(0)}"
                              : " \$${total.value.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: kDark,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  controller.defaultAddress == null
                      ? CustomButton(
                    onTap: () {
                      Get.to(() => const AddNewPlace());
                    },
                    radius: 9,
                    color: kPrimary,
                    btnWidth: width * 0.85,
                    btnHieght: 34.h,
                    text: "Add Default Address",
                  )
                      : orderController.isLoading
                      ? Center(
                    child: LoadingAnimationWidget.waveDots(
                      color: kPrimary,
                      size: 35
                    ),
                  )
                      : Expanded(
                    child: CustomButton(
                      onTap: () {
                        if (distanceTime.value!.distance > 10.0) {
                          Get.snackbar(
                            colorText: kDark,
                            backgroundColor: kOffWhite,
                            "Distance Alert",
                            "You are too far from the restaurant, please order from a restaurant closer to you ",
                          );
                          return;
                        } else {
                          print(paymentMethod);

                          Order order = Order(
                              userId: controller.defaultAddress!.userId,
                              orderItems: matchingCarts,
                              orderTotal: orderSubTotal.value.toStringAsFixed(2),
                              restaurantAddress: restaurant.coords.address,
                              restaurantCoords: [
                                restaurant.coords.latitude,
                                restaurant.coords.longitude,
                              ],
                              recipientCoords: [
                                controller.defaultAddress!.latitude,
                                controller.defaultAddress!.longitude,
                              ],
                              deliveryFee: totalDeliveryOptionPrice.value.toStringAsFixed(2),
                              grandTotal: total.value.toStringAsFixed(0),
                              deliveryAddress: controller.defaultAddress!.id,
                              paymentMethod: paymentMethod,
                              restaurantId: restaurant.id!,
                              deliveryOption: deliveryOption
                          );

                          String orderData = orderToJson(order);

                          orderController.order = order;

                          orderController.createOrder(orderData, order);
                        }
                      },
                      radius: 24,
                      color: kPrimary,
                      btnWidth: width * 0.90,
                      btnHieght: 50.h,
                      text: "Proceed to payment",
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

