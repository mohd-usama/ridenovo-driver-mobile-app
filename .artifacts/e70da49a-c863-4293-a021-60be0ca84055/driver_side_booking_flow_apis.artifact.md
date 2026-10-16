# Ridenova Driver Mobile App - Booking Flow APIs Documentation

This document provides a comprehensive list of all REST API endpoints, request payloads, query parameters, and response structures used during the driver booking and ride execution flow.

---

## Base URL & Headers
- **Base URL**: `http://103.160.107.238:5000/api`
- **Headers**:
  ```http
  Authorization: Bearer <driver_auth_token>
  Content-Type: application/json
  Accept: application/json
  ```

---

## 1. Duty Status & Location APIs

### A. Go Online
- **Method**: `POST`
- **Endpoint**: `/driver/online`
- **Request Body**:
  ```json
  {
    "battery": 85
  }
  ```
- **Response [200 OK]**:
  ```json
  {
    "success": true,
    "status": "success",
    "message": "Driver is now online",
    "timestamp": "2026-10-11T07:00:00.000Z"
  }
  ```

### B. Go Offline
- **Method**: `POST`
- **Endpoint**: `/driver/offline`
- **Response [200 OK]**:
  ```json
  {
    "success": true,
    "status": "success",
    "message": "Driver is now offline",
    "timestamp": "2026-10-11T07:00:00.000Z"
  }
  ```

### C. Update Live Location
- **Method**: `POST`
- **Endpoint**: `/driver/location`
- **Request Body**:
  ```json
  {
    "lat": 28.6180,
    "lng": 77.3890
  }
  ```
- **Response [200 OK]**:
  ```json
  {
    "success": true,
    "status": "success",
    "message": "Location updated successfully"
  }
  ```

---

## 2. Ride Request & Acceptance Flow APIs

### A. Get Pending Ride Requests
- **Method**: `GET`
- **Endpoint**: `/driver/ride-requests`
- **Response [200 OK]**:
  ```json
  {
    "success": true,
    "status": "success",
    "message": "Pending requests fetched",
    "data": {
      "requests": [
        {
          "id": "a052cb33-5adc-4de5-abb9-79792a51d56c",
          "rideId": "a052cb33-5adc-4de5-abb9-79792a51d56c",
          "status": "searching",
          "fare": 220,
          "distanceKm": 21.74,
          "durationMins": 52,
          "distanceToPickupKm": 1.2,
          "paymentMethod": "CASH",
          "vehicleType": "Bike",
          "pickup": {
            "address": "G94, Sector 63, Noida, Uttar Pradesh",
            "lat": 28.6175391,
            "lng": 77.3897194
          },
          "drop": {
            "address": "New Delhi Railway Station, New Delhi",
            "lat": 28.6402816,
            "lng": 77.2204103
          },
          "rider": {
            "id": "9bc77eac-b799-4033-8919-5e834499d2e8",
            "fullName": "Customer Name",
            "phone": "9638527410"
          },
          "createdAt": "2026-10-11T06:44:39.678337+00:00"
        }
      ]
    }
  }
  ```

### B. Accept Ride Request
- **Method**: `POST`
- **Endpoint**: `/driver/ride-requests/{ride_id}/accept` (Supports alias `/driver/riderequests/{ride_id}/accept`)
- **Response [200 OK]**:
  ```json
  {
    "success": true,
    "status": "success",
    "message": "Ride accepted successfully",
    "data": {
      "id": "3d2d01cd-3c67-4169-bbbb-a0aac57c0fed",
      "rideId": "3d2d01cd-3c67-4169-bbbb-a0aac57c0fed",
      "status": "accepted",
      "fare": 220,
      "pickup": {
        "address": "G94, Sector 63, Noida",
        "lat": 28.6175,
        "lng": 77.3897
      },
      "drop": {
        "address": "New Delhi Railway Station",
        "lat": 28.6402,
        "lng": 77.2204
      },
      "rider": {
        "id": "9bc77eac-b799-4033-8919-5e834499d2e8",
        "fullName": "Customer Name",
        "phone": "9638527410"
      },
      "route": {
        "distanceKm": 0.2,
        "durationMinutes": 1,
        "polyline": "kmtmDmbjwMuAGHaCfDL",
        "points": [
          { "lat": 28.61798, "lng": 77.38935 },
          { "lat": 28.61841, "lng": 77.38939 }
        ]
      }
    }
  }
  ```
- **Error Response [409 Conflict]**:
  ```json
  {
    "success": false,
    "status": "error",
    "errorCode": "REQUEST_ALREADY_TAKEN",
    "message": "Ride is no longer available or has already been accepted."
  }
  ```

### C. Reject Ride Request
- **Method**: `POST`
- **Endpoint**: `/driver/ride-requests/{ride_id}/reject`
- **Request Body**:
  ```json
  {
    "reason": "Too far"
  }
  ```
- **Response [200 OK]**:
  ```json
  {
    "success": true,
    "status": "success",
    "message": "Ride request rejected"
  }
  ```

---

## 3. Active Ride Execution APIs

### A. Get Ride Details / Active Ride
- **Method**: `GET`
- **Endpoint**: `/driver/rides/{ride_id}`
- **Response [200 OK]**:
  ```json
  {
    "success": true,
    "status": "success",
    "data": {
      "ride": {
        "id": "f590565b-4625-4daf-a5d4-378915840b87",
        "status": "accepted",
        "otp": "4819",
        "fare": 345,
        "payment_method": "cash",
        "pickup_address": "G94, Sector 63, Noida",
        "pickup_lat": 28.6175,
        "pickup_lng": 77.3897,
        "dropoff_address": "New Delhi Railway Station",
        "dropoff_lat": 28.6402,
        "dropoff_lng": 77.2204,
        "rider": {
          "fullName": "Customer Name",
          "phone": "9638527410"
        }
      }
    }
  }
  ```

### B. Get Route & Navigation Polyline
- **Method**: `GET`
- **Endpoint**: `/driver/rides/{ride_id}/route?lat={lat}&lng={lng}`
- **Query Parameters**:
  - `lat`: Driver current latitude (e.g., `28.6180`)
  - `lng`: Driver current longitude (e.g., `77.3890`)
- **Response [200 OK]**:
  ```json
  {
    "success": true,
    "status": "success",
    "message": "Route to pickup location calculated",
    "data": {
      "rideId": "3d2d01cd-3c67-4169-bbbb-a0aac57c0fed",
      "status": "accepted",
      "target": "pickup",
      "targetAddress": "G94, Sector 63, Noida",
      "targetLocation": {
        "lat": 28.6175391,
        "lng": 77.3897194
      },
      "driverLocation": {
        "lat": 28.618,
        "lng": 77.389
      },
      "distanceKm": 0.2,
      "durationMinutes": 1,
      "polyline": "kmtmDmbjwMuAGHaCfDL",
      "points": [
        { "lat": 28.61798, "lng": 77.38935 },
        { "lat": 28.61841, "lng": 77.38939 }
      ],
      "rider": {
        "fullName": "Customer Name",
        "phone": "9638527410"
      }
    }
  }
  ```

### C. Mark Arrived at Pickup
- **Method**: `POST`
- **Endpoint**: `/driver/rides/{ride_id}/arrived`
- **Response [200 OK]**:
  ```json
  {
    "success": true,
    "status": "success",
    "message": "Driver marked arrived at pickup"
  }
  ```

### D. Start Ride with OTP
- **Method**: `POST`
- **Endpoint**: `/driver/rides/{ride_id}/start`
- **Request Body**:
  ```json
  {
    "otp": "4819"
  }
  ```
- **Response [200 OK]**:
  ```json
  {
    "success": true,
    "status": "success",
    "message": "Ride started successfully"
  }
  ```
- **Error Response [400 Bad Request]**:
  ```json
  {
    "success": false,
    "status": "error",
    "errorCode": "INVALID_OTP",
    "message": "The OTP entered is incorrect. Please check with rider and try again."
  }
  ```

### E. Complete Ride
- **Method**: `POST`
- **Endpoint**: `/driver/rides/{ride_id}/complete`
- **Response [200 OK]**:
  ```json
  {
    "success": true,
    "status": "success",
    "message": "Ride completed successfully"
  }
  ```

### F. Cancel Ride
- **Method**: `POST`
- **Endpoint**: `/driver/rides/{ride_id}/cancel`
- **Request Body**:
  ```json
  {
    "reason": "Driver cancelled"
  }
  ```
- **Response [200 OK]**:
  ```json
  {
    "success": true,
    "status": "success",
    "message": "Ride cancelled successfully"
  }
  ```

### G. Rate Rider
- **Method**: `POST`
- **Endpoint**: `/driver/rides/{ride_id}/rate`
- **Request Body**:
  ```json
  {
    "rating": 5,
    "comment": "Great passenger!"
  }
  ```
- **Response [200 OK]**:
  ```json
  {
    "success": true,
    "status": "success",
    "message": "Rating submitted successfully"
  }
  ```

---

## 4. Real-time WebSocket Events (Socket.IO)

- **Connection URL**: `http://103.160.107.238:5000`
- **Incoming Events**:
  - `ride:new_request` / `ride.new_request`: Broadcasts when a new ride booking is created nearby.
  - `ride:status_changed` / `ride.status_changed`: Broadcasts when ride status updates (`accepted`, `arrived`, `started`, `completed`, `cancelled`).
- **Outgoing Events**:
  - `driver:location_update` / `updateLocation`: Emitted by driver app to push live GPS coordinates `{ lat, lng, heading, rideId }`.
