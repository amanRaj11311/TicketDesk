<a name="readme-top"></a>

<!-- PROJECT LOGO -->
<br />
<div align="center">
  <a href="https://github.com/your_username/TicketDesk">
    <!-- Replace with your actual logo URL if hosted -->
    <img src="assets/icons/app_icon.png" alt="TicketDesk Logo" width="100" height="100">
  </a>

  <h3 align="center">TicketDesk - Support Ticket Management System</h3>

  <p align="center">
    A powerful, role-based ticket management platform built for modern support teams.
    <br />
    <a href="https://github.com/your_username/TicketDesk/issues">Report Bug</a>
    ·
    <a href="https://github.com/your_username/TicketDesk/issues">Request Feature</a>
  </p>
</div>

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#key-features">Key Features</a></li>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#project-structure">Project Structure</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
  </ol>
</details>

<!-- ABOUT THE PROJECT -->
## About The Project

**TicketDesk** is a comprehensive, full-stack mobile application built with Flutter. It streamlines the customer support workflow by providing a centralized dashboard for tracking, assigning, and resolving user issues. 

Designed with a strict **Role-Based Access Control (RBAC)** system, the app dynamically adapts its UI and capabilities based on whether the user is an Admin, Support Agent, or a standard User. 

### Key Features

* 🎟️ **Ticket Lifecycle Management:** Create, assign, update priority/status, and resolve support tickets efficiently.
* 💬 **Real-time Live Chat:** Seamless ticket commenting system with background polling for instant app-to-app and app-to-web synchronization.
* 👥 **User & Role Administration:** Admins can manage users, assign roles, and handle strict system permissions right from the app.
* 🏢 **Team Organization:** Group support agents into specific teams with designated Team Leads.
* 📎 **Rich Media Support:** Easily attach, view, and directly download images associated with tickets and comments.
* 📊 **Dynamic Dashboard:** Real-time KPI metrics, open/closed ticket tracking, and quick navigation actions.
* 🌓 **Adaptive Theming:** Built-in seamless Light and Dark mode using Provider.
* 🔐 **Enterprise-Grade Security:** JWT token-based authentication with `flutter_secure_storage`.
* ⚡ **Optimized Performance:** Implementing infinite scrolling (pagination) and efficient memory cleanup.

### Built With

This project heavily leverages the modern Flutter ecosystem and external packages:

* [![Flutter][Flutter-badge]][Flutter-url]
* [![Dart][Dart-badge]][Dart-url]
* **Provider** - For robust State & Theme Management
* **Dio** - For advanced HTTP networking and API integration
* **Flutter Secure Storage** - For encrypted local token storage
* **Image Picker** - For handling media attachments

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- GETTING STARTED -->
## Getting Started

To get a local copy up and running, follow these simple steps.

### Prerequisites

Ensure you have the following installed on your local development environment:
* Flutter SDK (`^3.5.0` or higher)
* Dart SDK
* Android Studio / VS Code
* An active backend API serving the TicketDesk endpoints.

### Installation

1. Clone the repo
```bash
   git clone [https://github.com/your_username/TicketDesk.git](https://github.com/your_username/TicketDesk.git)
