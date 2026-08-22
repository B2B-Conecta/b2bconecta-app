// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

import 'meta_pixel_config.dart';

bool _scriptReady = false;
bool _pageViewSent = false;

/// Carga el Pixel y dispara [PageView] una sola vez por carga de página.
void syncMetaPixel({required bool marketingAllowed}) {
  if (!marketingAllowed) return;
  _ensureScript();
  _trackPageViewOnce();
}

void _ensureScript() {
  if (_scriptReady) return;
  if (js.context.hasProperty('fbq')) {
    _scriptReady = true;
    return;
  }
  final id = MetaPixelConfig.pixelId;
  js.context.callMethod('eval', [
    '''
    !function(f,b,e,v,n,t,s){if(f.fbq)return;n=f.fbq=function(){n.callMethod?
    n.callMethod.apply(n,arguments):n.queue.push(arguments)};
    if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';
    n.queue=[];t=b.createElement(e);t.async=!0;
    t.src=v;s=b.getElementsByTagName(e)[0];
    s.parentNode.insertBefore(t,s)}(window, document,'script',
    'https://connect.facebook.net/en_US/fbevents.js');
    fbq('init', '$id');
    ''',
  ]);
  _scriptReady = true;
}

void _trackPageViewOnce() {
  if (_pageViewSent) return;
  if (!js.context.hasProperty('fbq')) return;
  js.context.callMethod('fbq', ['track', 'PageView']);
  _pageViewSent = true;
}
