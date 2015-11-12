Phlist

Phlist (from "PHoto LIST") is an app that allows users to create and maintain 
collaborative lists of items with optional photo images - a grocery list in 
which the wife can enter items and add photos to insure her husband purchases 
the correct products, for example.

Data is stored locally on the device (with CoreData) and, to support 
collaboration, it is synchronized with the cloud (via Parse). To enable 
synchronization and sharing, the user is required to create an account (email 
and password).

The initial flow will present the user with a Welcome screen that displays 
information and buttons to navigate to either a signup screen or a login screen 
for existing users. There is also a "forgot password" screen that will initiate 
a password reset function. Once the user has logged in, she will remain logged 
in until manually logging out.

Upon login (or launch, if already logged in), the app loads all lists for which 
the user is the creator or editor. If any outstanding invitations exist, a 
confirmation dialog will be displayed allowing the user to accept or decline to 
share the lists.

That Lists view also includes controls to Edit the lists (removing lists), add 
a new list, log out, and refresh. The list of lists can also be refreshed with 
a pull-down gesture. 

Selecting a list displays its items in the List Items view. That view includes 
controls to add a new item, remove the list for the user's account, or manage 
the sharing. The list can be refreshed with a pull-down gesture.

The user can view the Sharing screen to see other members that share the list 
and to invite other users to share the list by entering the invitee's email.

When viewing the items in a list, the items are broken into two sections, 
Active and Archived. The active items are displayed with a name and a thumbnail 
(or placeholder) of the optional photograph. 

Tapping an active item removes it from the Active section and moves it into the 
Archived section, displaying it as "crossed out" (to indicated completion, 
purchase, etc.). Tapping an archived item returns it to the Active section.

Swiping an item to the left reveals a Delete button so the item can be removed.

Tapping the thumbnail/placeholder image will display the item details, 
consisting of the name and a larger view of the image. The name can be edited 
in a text field. Tapping the large image will allow the user to replace the 
existing image with a new one from his camera or photo library, which will be 
saved at a suitable resolution and compression so as to not occupy unnecessary 
drive space.


Notes:

I encourage testers to create multiple accounts to experience the sharing 
feature.

Virtually all tasks include immediately saving edits locally and in the cloud. 
Since multiple editors might be making changes, each new presentation (e.g. 
navigating into our out of a list) includes a synchronization request. 

In most cases, a lack of network connectivity will result in a silent failure, 
allowing for later synchronization. The connectivity state is observed so most 
cloud requests are conditional on an active connection to avoid delaying the 
user experience.

Using the Parse SDK, the cloud data and methods are integrated into the model 
to best insure synchronization. While the managed data classes include a 
reference to their corresponding cloud objects, all other references to the 
cloud data objects and architecture are contained within a single 
ModelController class. This abstracts the model from the view (presentation and 
behavior). If the decision was made to switch from Parse to an alternate cloud 
solution, all changes would take place in ModelController and the three managed 
data classes.
