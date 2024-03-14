import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'pages/consts.dart';
import 'package:weather/weather.dart';
import 'package:anim_search_bar/anim_search_bar.dart';

import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue, // สามารถปรับเปลี่ยนได้ตามต้องการ
        scaffoldBackgroundColor: Color.fromARGB(255, 183, 222, 220), // ตั้งสีพื้นหลังของ scaffold
        // เพิ่มเติมอื่น ๆ ตามที่ต้องการ
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late bool servicePermission;
  late LocationPermission permission;
  
  

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 20).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocationAndNavigate() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, so we request them.
      await Geolocator.openLocationSettings();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        // Permissions are denied.
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever.
      return;
    } 

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    Position position = await Geolocator.getCurrentPosition();
    
    WeatherFactory _weatherFactory = WeatherFactory(OPENWEATHER_API_KEY);
    Weather _weather = await _weatherFactory.currentWeatherByLocation(
      position.latitude, 
      position.longitude,
    );

    // Navigate to the GeolocationApp page and pass the Position and Weather data.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GeolocationApp(
          location: position,
          weather: _weather,
        ),
      ),
    );
  }

  // ... Rest of your _HomePageState code

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 127, 212, 207),
        title: const Text("Open Weather API",
          style: const TextStyle(
            shadows: [
              Shadow(
                  blurRadius: 10.0,
                  color: Colors.blue,
                  offset: Offset(5.0, 5.0),
                  ),
            ],
            color: Color.fromARGB(255, 255, 255, 255),
            fontSize: 30, 
            fontWeight: FontWeight.bold
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            GestureDetector(
              onTap: _getCurrentLocationAndNavigate, // Call the function when the image is tapped.
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _animation.value),
                    child: child,
                  );
                },
                child: Image.asset(
                  'assets/sun-and-cloud-kawaii-weather-vector-45158063-Photoroom.png-Photoroom.png',
                ),
              ),
            ),
            // Rest of your widget tree
          ],
        ),
      ),
    );
  }
}



class HourlyWeather {
  final String time; // ใช้ String เพื่อเก็บ dt_txt
  final String des;
  final double temperature;
  final String icon;

  HourlyWeather({required this.time, required this.des, required this.temperature, this.icon=''});
}

class GeolocationApp extends StatefulWidget {
  final Position? location;
  final Weather? weather;
  const GeolocationApp({Key? key, this.weather, this.location}) : super(key: key);

  @override
  _GeolocationAppState createState() => _GeolocationAppState();
}

class _GeolocationAppState extends State<GeolocationApp> {
  Position? _currentLocation;
  late bool servicePermission = false;
  late LocationPermission permission;
  String _currentAddress = "";
  Weather? _weather;
  TextEditingController textController = TextEditingController(text: ""); // Controller for search input

  String _getIconUrl(String iconCode) {
  return 'https://openweathermap.org/img/wn/$iconCode@2x.png';
  }

  Future<Position> _getCurrentLocation() async {
    servicePermission = await Geolocator.isLocationServiceEnabled();
    if (!servicePermission) {
      print("service disabled");
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return await Geolocator.getCurrentPosition();
  }

  void _fetchWeatherData3() {
  if (widget.location != null) {
    _getAddressFromCoordinates(widget.location!);
    _fetchWeatherData2(widget.location!.latitude, widget.location!.longitude);
  }
  }

  @override
  void initState() {
    super.initState();
    _fetchWeatherData3();
    // If location data is passed, use it directly.
    if (widget.location != null) {
      _getAddressFromCoordinates(widget.location!);
      _fetchHourlyWeatherData(widget.location!.latitude, widget.location!.longitude, OPENWEATHER_API_KEY);
    }
  }

  Future<String> _getAddressFromCoordinates(Position position) async {
    List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
    Placemark place = placemarks[0];
    String cityName = "${place.subAdministrativeArea} : ${place.administrativeArea}";

    setState(() {
      _currentAddress = cityName;
    });
    
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      Placemark place = placemarks[0];
      String cityName = "${place.subAdministrativeArea} : ${place.administrativeArea}";

      setState(() {
        _currentAddress = cityName;
      });

      return cityName;
    } catch (e) {
      print(e);
      return "";
    }
  }

  final WeatherFactory _wf = WeatherFactory(OPENWEATHER_API_KEY);

  _fetchWeatherData(Position position) {
    if (widget.location != null) {
      _getAddressFromCoordinates(widget.location!);
      _fetchWeatherData2(widget.location!.latitude, widget.location!.longitude);
    }
    _getAddressFromCoordinates(position).then((address) {
      setState(() {
        _currentAddress = address;
      });
    });
    _wf.currentWeatherByLocation(position.latitude, position.longitude).then((w) {
      setState(() {
        _weather = w;
      });
    });
  }

  _fetchWeatherData2(double latitude, double longitude) {
      _wf.currentWeatherByLocation(latitude, longitude).then((w) {
        setState(() {
          _weather = w;
        });
      });
    }

  _fetchWeatherSearchBar(String cityName) async {
    try {
      // Use Geocoding API to fetch location data from the city name
      List<Location> locations = await locationFromAddress(cityName);
      if (locations.isNotEmpty) {
        // Select the first location in the list
        final latitude = locations[0].latitude;
        final longitude = locations[0].longitude;

        // Update the current address
        setState(() {
          _currentAddress = cityName;
        });

        // Fetch weather data using the obtained coordinates
        _fetchWeatherData2(latitude, longitude);
        // Fetch hourly weather data for the specified coordinates
        _fetchHourlyWeatherData(latitude, longitude, OPENWEATHER_API_KEY);
      } else {
        // If locations list is not empty but no result is found
        print('Location not found for $cityName');
        // Provide feedback to the user that the location was not found
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location not found for $cityName'),
          ),
        );
      }
    } catch (error) {
      // Handle the error here
      print('Error fetching location: $error');
      // Set _currentAddress to an error message or handle it as needed
      setState(() {
        _currentAddress = 'Please search a correct location!';
      });
    }
  }




  List<HourlyWeather> threeHourlyWeather = []; // ปรับปรุงเป็น List ของ HourlyWeather
  

  void _fetchHourlyWeatherData(double lat, double lon, String apiKey) async {
  final url = Uri.parse('https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$apiKey');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final jsonData = json.decode(response.body);
    setState(() {
      threeHourlyWeather = List<HourlyWeather>.from(
        jsonData['list'].map(
          (item) {
            // แปลงอุณหภูมิจาก Kelvin เป็น Celsius
            final double tempCelsius = item['main']['temp'].toDouble() - 273.15;
            return HourlyWeather(
              time: item['dt_txt'], // ใช้ dt_txt จากข้อมูล
              des: item['weather'][0]['description'].toString(),
              // เก็บค่าอุณหภูมิใน Celsius
              temperature: tempCelsius,
              icon: item['weather'][0]['icon'].toString(),
            );
          },
        ),
      );
    });
  } else {
    print('Failed to load data: ${response.statusCode}');
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 127, 212, 207),
        title: const Text("Open Weather API",
          style: const TextStyle(
            shadows: [
              Shadow(
                  blurRadius: 10.0,
                  color: Colors.blue,
                  offset: Offset(5.0, 5.0),
                  ),
            ],
            color: Color.fromARGB(255, 255, 255, 255),
            fontSize: 30, 
            fontWeight: FontWeight.bold
          ),
        ),
        centerTitle: true,
        actions: [
          AnimSearchBar(
            width: 300,
            helpText: "Enter city name...",
            textController: textController,
            onSubmitted: (value) {
              _fetchWeatherSearchBar(value);
            },
            onSuffixTap: (value) {
              _fetchWeatherSearchBar(value);
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(
              height: 20,
            ),
            ElevatedButton(
              onPressed: () async {
                _currentLocation = await _getCurrentLocation();
                await _getAddressFromCoordinates(_currentLocation!);
                _fetchWeatherData(_currentLocation!);
                _fetchHourlyWeatherData(_currentLocation!.latitude, _currentLocation!.longitude, (OPENWEATHER_API_KEY));
              },
              child: const Text("Current Location"),
            ),
            const SizedBox(
              height: 15,
            ),
            Text("Current Location",
              style: const TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold),
            ),
            const SizedBox(
              height: 5,
            ),
            Text("$_currentAddress",
              style: const TextStyle(
                  fontSize: 20, 
                ),
            ),
            const SizedBox(
              height: 10,
            ),
            if (_weather != null) // ตรวจสอบว่ามีข้อมูลสภาพอากาศหรือไม่
            Text(
              "${_weather!.temperature?.celsius?.toStringAsFixed(0)}°",
              style: const TextStyle(
                fontSize: 100,
                fontWeight: FontWeight.bold
                ),
            ),
            const SizedBox(
              height: 10,
            ),
            Text(
              "${_weather?.weatherDescription}",
              style: const TextStyle(
                fontSize: 20, 
              ),
            ),
            const SizedBox(
              height: 5,
            ),
            Container(
              width: double.infinity, // This makes the Container take all available horizontal space
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center, // This centers the Row content horizontally
                children: [
                  Text(
                    "High: ${_weather?.tempMax?.celsius?.toStringAsFixed(0)}°  ",
                    style: const TextStyle(
                      fontSize: 15, 
                    ),
                  ),

                  Text(
                    "Low: ${_weather?.tempMin?.celsius?.toStringAsFixed(0)}°",
                    style: const TextStyle(
                      fontSize: 15, 
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Color.fromARGB(184, 240, 240, 240), // หรือสีที่คุณต้องการใช้
                  borderRadius: BorderRadius.circular(12.0), // ถ้าต้องการมีมุมโค้ง
                ),
                margin: EdgeInsets.all(8.0), // ใส่ขอบรอบๆ Container
                padding: EdgeInsets.all(8.0), 
                child: ListView.builder(
                  itemCount: threeHourlyWeather.length,
                  itemBuilder: (context, index) {
                    final weather = threeHourlyWeather[index];

                    // แปลงสตริงเวลาให้เป็น DateTime
                    final dateTime = DateFormat('yyyy-MM-dd HH:mm:ss').parse(weather.time);
                    // จัดรูปแบบเวลาให้เป็นชั่วโมงและนาที
                    final timeFormatted = DateFormat('dd/MM HH:mm').format(dateTime);

                    return ListTile(
                      title: Text(timeFormatted), // แสดงเวลาที่จัดรูปแบบแล้ว
                      subtitle: Row(
                        children: [
                          Image.network(_getIconUrl(weather.icon)), // แสดงไอคอนสภาพอากาศ
                          SizedBox(width: 15), // เพิ่มระยะห่างระหว่างไอคอนและข้อความ
                          Text(
                            weather.des,
                            style: TextStyle(
                              fontSize: 20, 
                            ),
                          ),
                        ],
                      ),
                      trailing: Text('${weather.temperature.toStringAsFixed(0)}°',
                        style: TextStyle(
                              fontSize: 27, 
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}