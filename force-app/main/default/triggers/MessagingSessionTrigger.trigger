trigger MessagingSessionTrigger on MessagingSession (after update) {
    MyTriggers.run();
}