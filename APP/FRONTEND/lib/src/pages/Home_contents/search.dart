import 'dart:convert';
import 'package:ev_app/src/pages/Charging/charging.dart';
import 'package:ev_app/src/pages/home.dart';
import 'package:ev_app/src/service/location.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class SearchResultsPage extends StatefulWidget {
  final Future<Map<String, dynamic>?> Function(String) handleSearchRequest;
  final Function(Map<String, dynamic>)
      onLocationSelected; // Callback to handle selected location
  final String username;
  final int? userId;
  final String email;

  const SearchResultsPage(
      {super.key,
      required this.handleSearchRequest,
      required this.onLocationSelected,
      required this.username,
      this.userId,
      required this.email});

  @override
  _SearchResultsPageState createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  final TextEditingController _chargerIdController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // Sample recent locations
  List<Map<String, String>> recentLocations = [];
  List<Map<String, Object>> filteredLocations = [];
  LatLng? _currentPosition;
  bool _isLoading = false; // Add this variable to manage loading state
  bool _isLoadingBolt = false; // Add this variable to manage loading state
  bool _isDialogShown = false;

  // Initialize recent locations from SharedPreferences
  @override
  void initState() {
    super.initState();
    _loadRecentLocations();
  }

  void _searchChargerId(String chargerId) async {
    if (chargerId.isEmpty) {
      // Handle empty charger ID input
      return;
    }

    final result = await widget.handleSearchRequest(chargerId);

    if (result != null && result.containsKey('error') && !result['error']) {
      // If search is successful, prepare location data
      final location = {
        'name': result['chargerName']?.toString() ??
            'Unknown Charger', // Ensure value is a String
        'address': result['chargerAddress']?.toString() ??
            '', // Ensure value is a String
      };

      // Call the onLocationSelected method to locate the charger on the map
      _onLocationSelected(location);
    } else {
      // Handle error cases
      print('Error in search: ${result?['message']}');
    }
  }

  void _oncurrentLocationSelected(Map<String, dynamic> location) {
    // Convert latitude and longitude to strings to ensure consistency
    final selectedLocation = {
      'name': location['name'],
      'address': location['address'],
      'latitude': location['latitude'].toString(), // Ensure it's a string
      'longitude': location['longitude'].toString(), // Ensure it's a string
    };

    // Pass the selected location to the callback
    widget.onLocationSelected(selectedLocation);

    print("_currentSelectedLocation $selectedLocation");

    // Use Navigator.push to add the new page without disrupting other content
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(
          selectedLocation:
              selectedLocation, // Pass the consistent selectedLocation
          username: widget.username,
          userId: widget.userId,
          email: widget.email,
        ),
      ),
    );
  }

  void _onLocationSelected(Map<String, dynamic> location) {
    // Convert latitude and longitude to strings to ensure consistency
    final selectedLocation = {
      'name': location['name'],
      'address': location['address'],
      'latitude': location['latitude'].toString(), // Ensure it's a string
      'longitude': location['longitude'].toString(), // Ensure it's a string
    };

    // Pass the selected location to the callback
    widget.onLocationSelected(selectedLocation);

    _saveRecentLocation(location); // Save selected location to recent
    print("_currentSelectedLocation $selectedLocation");

    // Use Navigator.push to add the new page without disrupting other content
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(
          selectedLocation:
              selectedLocation, // Pass the consistent selectedLocation
          username: widget.username,
          userId: widget.userId,
          email: widget.email,
        ),
      ),
    );
  }

  Future<void> _loadRecentLocations() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? storedLocations = prefs.getStringList('recentLocations');

    if (storedLocations != null) {
      recentLocations = storedLocations.map((location) {
        var parts = location.split('|');
        return {
          'name': parts[0],
          'address': parts[1],
          'latitude': parts[2],
          'longitude': parts[3],
        };
      }).toList();

      setState(() {});
    }
  }

  Future<void> _saveRecentLocation(Map<String, dynamic> location) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    print("location: $location");

    // Ensure all values in location are Strings
    final locationAsStringMap = {
      'name': location['name'].toString(),
      'address': location['address'].toString(),
      'latitude': location['latitude'].toString(),
      'longitude': location['longitude'].toString(),
    };

    // Check if the location already exists in recentLocations
    if (!recentLocations.any((loc) =>
        loc['name'] == locationAsStringMap['name'] &&
        loc['address'] == locationAsStringMap['address'])) {
      // Add to the top of the list
      recentLocations.insert(0, locationAsStringMap);

      // Convert the recentLocations list to a List<String> for storage, including latitude and longitude
      List<String> storedLocations = recentLocations.map((loc) {
        return '${loc['name']}|${loc['address']}|${loc['latitude']}|${loc['longitude']}';
      }).toList();

      // Save the recent locations list to SharedPreferences
      await prefs.setStringList('recentLocations', storedLocations);

      // Update the UI
      setState(() {});
    }
  }

  Future<void> _clearRecentLocations() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('recentLocations'); // Clear from SharedPreferences
    setState(() {
      recentLocations.clear(); // Clear the local list
    });
  }

  Future<void> _deleteRecentLocation(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    recentLocations.removeAt(index); // Remove the location from the local list
    List<String> storedLocations = recentLocations
        .map((loc) => '${loc['name']}|${loc['address']}')
        .toList();
    await prefs.setStringList(
        'recentLocations', storedLocations); // Update SharedPreferences
    setState(() {}); // Update the UI
  }

  Future<List<Map<String, dynamic>>> fetchLocations(String query) async {
    const String apiKey =
        'AIzaSyDezbZNhVuBMXMGUWqZTOtjegyNexKWosA'; // Replace with your actual API key
    final String apiUrl =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        // Decode the JSON response
        Map<String, dynamic> data = json.decode(response.body);

        // Extract the predictions
        List<dynamic> predictions = data['predictions'] ?? [];

        // Create a list to store locations with additional details
        List<Map<String, dynamic>> locations = [];

        // Fetch details for each prediction
        for (var item in predictions) {
          String placeId = item['place_id'];
          String name = item['description'];

          // Fetch Place Details
          final detailsResponse = await http.get(Uri.parse(
              'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$apiKey'));

          if (detailsResponse.statusCode == 200) {
            Map<String, dynamic> detailsData =
                json.decode(detailsResponse.body);
            var locationData = detailsData['result']['geometry']['location'];

            // Extract latitude and longitude
            double latitude = locationData['lat'];
            double longitude = locationData['lng'];

            // Extract address
            String address =
                item['structured_formatting']['secondary_text'] ?? '';

            // Add location data to the list
            locations.add({
              'name': name,
              'address': address,
              'latitude': latitude,
              'longitude': longitude,
            });
          } else {
            print(
                'Failed to load place details for $placeId, status code: ${detailsResponse.statusCode}');
          }
        }

        // Filter to only include locations in India
        return locations
            .where((location) => location['address']!.contains('India'))
            .toList();
      } else {
        throw Exception(
            'Failed to load locations, status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching locations: $e');
      return []; // Return an empty list in case of an error
    }
  }

  void _filterLocations(String query) async {
    // Clear previous filtered locations when query is empty
    if (query.isEmpty) {
      setState(() {
        filteredLocations = [];
        _isLoading = false; // Set loading to false if no query
      });
      return; // Exit early
    }

    // Set loading to true before fetching locations
    setState(() {
      _isLoading = true;
    });

    // Fetch locations based on the query
    List<Map<String, dynamic>> locations = await fetchLocations(query);

    setState(() {
      // Print the filtered locations
      for (var location in locations) {
        print('Name: ${location['name']}');
        print('Address: ${location['address']}');
        print('Latitude: ${location['latitude']}');
        print('Longitude: ${location['longitude']}');
        print(''); // Just for better formatting
      }

      // Update the filtered locations
      filteredLocations = locations.map((location) {
        return {
          'name': location['name'] as String,
          'address': location['address'] as String,
          'latitude': location['latitude'] as double,
          'longitude': location['longitude'] as double,
        };
      }).toList();

      // Set loading to false after fetching locations
      _isLoading = false;
    });
  }

  Future<void> _showLocationServicesDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E), // Background color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.location_on, color: Colors.red, size: 35),
                  SizedBox(width: 10),
                  Expanded(
                    // Add this to prevent the overflow issue
                    child: Text(
                      "Enable Location", // The heading text
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow
                          .ellipsis, // Optional: add ellipsis if text overflows
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              CustomGradientDivider(), // Custom gradient divider
            ],
          ),
          content: const Text(
            'Location services are required to use this feature. Please enable location services in your phone settings.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white70), // Adjusted text color for contrast
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                // Save the flag to not show the dialog again
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.setBool('LocationPromptClosed', true);
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text(
                "Close",
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () async {
                await Geolocator
                    .openLocationSettings(); // Open the location settings
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text(
                "Settings",
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }


  Future<void> _showPermissionDeniedDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E), // Background color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.location_on, color: Colors.red, size: 35),
                  SizedBox(width: 10),
                  Expanded(
                    // Prevent text overflow
                    child: Text(
                      "Permission Denied",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow
                          .ellipsis, // Optional: add ellipsis if text overflows
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              CustomGradientDivider(), // Custom gradient divider
            ],
          ),
          content: const Text(
            'This app requires location permissions to function correctly. Please grant location permissions in settings.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white70), // Adjusted text color for contrast
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () async {
                openAppSettings(); // Open app settings
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text(
                "Settings",
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }


  Future<void> _showPermanentlyDeniedDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E), // Background color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 35),
                  SizedBox(width: 10),
                  Expanded(
                    // Prevent text overflow
                    child: Text(
                      "Permission Denied",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow
                          .ellipsis, // Optional: add ellipsis if text overflows
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              CustomGradientDivider(), // Custom gradient divider
            ],
          ),
          content: const Text(
            'Location permissions are permanently denied. Please enable them in the app settings.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white70), // Adjusted text color for contrast
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () async {
                openAppSettings(); // Open app settings
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text(
                "Settings",
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _getCurrentLocation() async {
    try {
     // Ensure location services are enabled and permission is granted before fetching location
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _showLocationServicesDialog();
        return;
      }

      PermissionStatus permission = await Permission.location.status;
      if (permission.isDenied) {
        await _showPermissionDeniedDialog();
        return;
      } else if (permission.isPermanentlyDenied) {
        await _showPermanentlyDeniedDialog();
        return;
      }

      // Fetch the current location if permission is granted
      LatLng? currentLocation =
          await LocationService.instance.getCurrentLocation();
      print("_onMapCreated currentLocation $currentLocation");

      if (currentLocation != null) {
        // Update the current position
        setState(() {
          _currentPosition = currentLocation;
        });

        // Call the _onLocationSelected function with the current location data
        _oncurrentLocationSelected({
          'name': 'Current Location',
          'address': 'Your Current Address', // You can customize this as needed
          'latitude': currentLocation.latitude.toString(),
          'longitude': currentLocation.longitude.toString(),
        });
      } else {
        print('Current location could not be determined.');
      }
    } catch (e) {
      print('Error occurred while fetching the current location: $e');
    }
  }

  void _showsDialog() {
    // Show the loading animation
    showDialog(
      context: context,
      barrierDismissible:
          false, // Prevents dismissing the dialog by tapping outside
      builder: (BuildContext context) {
        return Center(
          child: SizedBox(
            child: _AnimatedChargingIcon(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isSmallScreen = width < 600;

    // Use Future.microtask to avoid calling setState during build
    if (_isLoadingBolt && !_isDialogShown) {
      _isDialogShown = true; // Add this variable
      Future.microtask(() => _showsDialog());
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          '',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 8.0 : 16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: isSmallScreen ? 8.0 : 16.0),
              TextField(
                controller: _chargerIdController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color.fromARGB(200, 58, 58, 60),
                  prefixIcon: const Icon(Icons.ev_station, color: Colors.green),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.search,
                      color: Colors.white70,
                      size: 23,
                    ),
                    onPressed: () {
                      // Dismiss the keyboard
                      FocusScope.of(context).unfocus();
                      // Delay for 1 second before executing further logic
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (_chargerIdController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a Charger ID.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          setState(() {
                            _isLoadingBolt = false;
                            _isDialogShown = false; // Reset dialog shown status
                          });
                        } else {
                          setState(() {
                            _isLoadingBolt = true;
                          });

                          _searchChargerId(_chargerIdController.text);
                        }
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  hintText: 'Search by ChargerID...',
                  hintStyle: const TextStyle(color: Colors.grey),
                ),
                onSubmitted: (value) {
                  // Dismiss the keyboard
                  FocusScope.of(context).unfocus();

                  setState(() {
                    _isLoadingBolt = true;
                  });

                  Future.delayed(const Duration(seconds: 1), () {
                    if (value.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a Charger ID.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      setState(() {
                        _isLoadingBolt = false;
                        _isDialogShown = false; // Reset dialog shown status
                      });
                    } else {
                      _searchChargerId(value);
                    }
                  });
                },
                cursorColor: const Color(0xFF1ED760),
              ),
              SizedBox(height: isSmallScreen ? 8.0 : 16.0),

              // Custom Gradient Divider with 'or' Text
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 1.0,
                      width: isSmallScreen ? 100 : 150,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green, Colors.greenAccent],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    const Text(
                      'OR',
                      style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Container(
                      height: 1.0,
                      width: isSmallScreen ? 100 : 150,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green, Colors.greenAccent],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: isSmallScreen ? 8.0 : 16.0),
              TextField(
                controller: _locationController,
                onChanged: _filterLocations,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color.fromARGB(200, 58, 58, 60),
                  prefixIcon:
                      const Icon(Icons.location_on, color: Colors.redAccent),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  hintText: 'Search by Location...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear,
                        color: Colors.white70, size: 23),
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      Future.delayed(const Duration(milliseconds: 500));

                      // Add a delay of 500 milliseconds before unfocusing the text field
                      // Clear the text field and filtered locations first
                      _locationController.clear();
                      setState(() {
                        filteredLocations = [];
                      });
                    },
                  ),
                ),
                cursorColor: const Color(0xFF1ED760),
              ),
              // Show loading indicator with message if _isLoading is true
              if (_isLoading)
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                          height: 13), // Space between the indicator and text
                      Text('Fetching locations...',
                          style: TextStyle(
                              fontSize: 16, color: Colors.orangeAccent)),
                      SizedBox(
                          height: 10), // Space between the indicator and text
                    ],
                  ),
                ),

              if (filteredLocations.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredLocations.length,
                  itemBuilder: (context, index) {
                    final location = filteredLocations[index];
                    return ListTile(
                      title: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('📍 ', style: TextStyle(fontSize: 20)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  location['name']
                                      as String, // Explicitly cast to String
                                  style: const TextStyle(color: Colors.green),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  location['address']
                                      as String, // Explicitly cast to String
                                  style: const TextStyle(color: Colors.grey),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        _locationController.text =
                            location['name'] as String; // Cast to String
                        _saveRecentLocation(location);
                        _onLocationSelected(location);
                        setState(() {
                          filteredLocations = [];
                          _isLoading = false;
                        });
                      },
                    );
                  },
                ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _getCurrentLocation, // Call the function here
                icon: const Icon(
                  Icons.my_location,
                  color: Colors.white,
                ), // Icon for current location
                label: const Text(
                  'Current location',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.green, // Set the button color to green
                  minimumSize: const Size(
                      double.infinity, 50), // Full width button and set height
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(8), // Optional: Rounded corners
                  ),
                ),
              ),

              const SizedBox(height: 10),
              Padding(
                padding: EdgeInsets.symmetric(
                    vertical: isSmallScreen ? 4.0 : 8.0, horizontal: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.history, color: Colors.grey, size: 20.0),
                        SizedBox(width: 8.0),
                        Text(
                          'Recent Locations',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        _clearRecentLocations();
                      },
                      child: const Text(
                        'Clear all',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Center(
                child: Container(
                  height: 0.5,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green, Colors.greenAccent],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentLocations.length,
                itemBuilder: (context, index) {
                  final location = recentLocations[index];
                  return Padding(
                    padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 4.0 : 8.0),
                    child: Card(
                      color: const Color.fromARGB(200, 58, 58, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 4,
                      child: InkWell(
                        onTap: () {
                          _onLocationSelected(location);
                        },
                        child: Padding(
                          padding: EdgeInsets.all(isSmallScreen ? 8.0 : 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      location['name']!,
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w400,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      location['address']!,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  _deleteRecentLocation(index);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedChargingIcon extends StatefulWidget {
  @override
  __AnimatedChargingIconState createState() => __AnimatedChargingIconState();
}

class __AnimatedChargingIconState extends State<_AnimatedChargingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..forward(); // Start the animation

    // Slide animation for moving the bolt icon vertically downwards
    _slideAnimation = Tween<double>(begin: -130.0, end: 60.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Opacity animation for smooth fading in and out
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Reset the animation to start from the top when it reaches the bottom
        _controller.reset();
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value), // Move vertically
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: child,
          ),
        );
      },
      child: const Icon(
        Icons.bolt_sharp, // Charging icon
        color: Colors.green, // Set the icon color
        size: 200, // Adjust the size as needed
      ),
    );
  }
}
