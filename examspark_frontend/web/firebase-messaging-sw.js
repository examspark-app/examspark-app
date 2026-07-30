// Native browser service worker handling placeholder for background tasks
self.addEventListener('backgroundfetchsuccess', (event) => {
    console.log('Background task synced natively.');
  });
  
  self.addEventListener('push', function (event) {
    if (event.data) {
      const data = event.data.json();
      const options = {
        body: data.notification.body,
        icon: '/icons/Icon-192.png', // Aapke web icons folder ka path
        data: data.data
      };
      event.waitUntil(
        self.registration.showNotification(data.notification.title, options)
      );
    }
  });
  