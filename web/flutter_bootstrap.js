{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
    timeoutMillis: 2000
  },
  config: {
    hostElement: document.querySelector('#flutter-app'),
  }
});
