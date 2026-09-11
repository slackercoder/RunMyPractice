# Functional Specification Document: RunMy Practice

## 1. Executive Summary
* **Project Overview:** A mobile app with potential api backing for data to run practices for your sport/game.
* **Problem Statement:** Running a practice can be complicated and complex. Coaches need a way to organize a practice. Simple to use, but effective management over most aspects of the practice.
* **Value Proposition:** The simplicity is essential. Everything else has a million ways to improved everything. Sometimes you need to step back and take it one small step at a time.

## 2. Target Audience & Personas
* **User Demographics:** Coaches and advisors of anything. Not just sports.
* **User Personas:** 
  * **Clark Kent - Curling Coach** Clark is an entry level curling coach that needs assistance with learning the ropes. Clark primarily coaches youth curling, with athlete ages ranging from 7 to 16.
  * **Bruce Wayne - TCG Mentor** Bruce teaches competative TCG players how to break through to the next level.

## 3. Scope of the Project
* **In-Scope (MVP):** 
  * Creating a practice schedule.
  * Executing/Interacting with the practice schedule
* **Out-of-Scope (Future Phases):** 
  * To Be Updated

## 4. User Architecture & Roles
* **User Types:** Registered User, Admin
* **Permissions Matrix:** 
  * **Registered User**: 
    * Create and maintain practice plans. 
    * Execute plans during practice.
  * **Admin**: 
    * Control user accounts (add/remove as needed). 
    * Edit static data (dropdown lists, etc)

## 5. Functional Requirements (Features)
*Use this section to break down specific features. Repeat this structure for each major feature.*

### 5.1 User Authentication
* **Description:** Authenticates and Authorizes the user.
* **User Story:** "As a user, I need to be able to login and be able to use my appropriate roles."
* **Acceptance Criteria:**
  * Must validate email format.
  * Passwords must be at least 8 characters.
  * Send a confirmation email upon registration.

### 5.2 Home Screen / Search
* **Description:** How users find practices, with the ability to start new ones from this point.
* **Acceptance Criteria:**
  * Users will get a list of available practices to view/execute. 
  * Users can search for practices by some criteria (to be defined).
  * Users will have the option of adding new practices.

### 5.3 Create a new Practice
* **Description** How users create a new practice.
* **Acceptance Criteria:**
  * Creating a practice using the tools provided.

### 5.4 View/Execute Practice
* **Description** How users view/execute a new practice.
* **Acceptance Criteria:**
  * Being able to see the existing practice.
  * Being able to interact with the practice to enter data required from the practice metrics.

### 5.5 Player/Athlete List
* **Description** The list of available players/athletes.
* **Acceptance Criteria:**
  * Being able to see the list of players/athletes.
  * Being able to add a new player/athlete
  * Being able to remove a player/athlete

## 6. User Experience (UX) & User Interface (UI)
* **User Flows:** 
  * **Create Practice Flow:** Start at home page. Click/Tap `Create New Practice` button. Enter view to create a practice.
  * **Edit Practice Flow:** Full view of editting a practice, whether an existing practice or a "new" blank practice.
  * **Execute Practice Flow:** Full view of executing a practice. Allowing the coach to enter data as required (creating teams for exercises, checking off completed tasks, scoring exercises, etc).
  * **User Edit Flow:** View the list of users and either add and/or remove users based on needs.
* **Wireframes/Mockups:** To be determined through discovery.
* **Design Guidelines:** No design guidelines yet. To be determined through discovery.

## 7. Technical & Non-Functional Requirements
* **Platform Requirements:** iOS (Swift), Web (Blazor), potentially expansion into Android.
* **Performance:** TBD
* **Security & Privacy:** Data encryption, biometric login support.
* **Localization:** English at launch. Potential to expand if market is there for it.

## 8. Data & Analytics
* **Data Models:** Users data (identifier such as a first name, but no real PII), Practice data, scoring, etc.
* **Key Metrics to Track:** TBD

## 9. Risks, Constraints, and Assumptions
* **Dependencies:** Potential use of `RunMy`'s Identity server and API platform for "cloud" storage of practice and analytics data.
* **Constraints:** Strict Deadlines. Season starts early October.
* **Assumptions:** 
 * Unlikely to have stable internet connect in the ice house.
 * User should have an available iPad (or potentially a future release for an Android tablet). 
