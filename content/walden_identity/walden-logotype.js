/**
 * <walden-logotype> Web Component
 *
 * A self-contained animated logotype for Walden. The letterforms oscillate
 * through weight (wght 200-700) and serif (SRFF 0-0.8) axes on irrational-
 * ratio periods so the combination never repeats. Hovering returns the
 * logotype to its resting state (wght 443, SRFF 0.5) at a constant speed.
 *
 * The font is subsetted to only WALDEN glyphs (~10 KB woff2) and base64-
 * encoded into this file - no external assets required.
 *
 * Usage:
 *   <script src="walden-logo.js"><\/script>
 *
 *   <!-- Set size directly -->
 *   <walden-logotype style="font-size: 80px;"><\/walden-logo>
 *
 *   <!-- Or fill a target width (accepts any CSS unit) -->
 *   <walden-logotype width="50vw"><\/walden-logo>
 *
 *   <!-- Use a different font file instead of the embedded one -->
 *   <walden-logotype src="./MyFont.ttf" style="font-size: 40px;"><\/walden-logo>
 *
 * The element is transparent, inherits color, and has no padding or margin.
 * Style it like any inline-block element.
 *
 * Respects prefers-reduced-motion - animation is skipped entirely.
 * Cleans up its rAF loop and resize observer when removed from the DOM.
 */

// Subsetted ABCArizonaPlusVariable (WALDEN glyphs only, wght + slnt + SRFF axes)
const WALDEN_FONT = "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";

class WaldenLogo extends HTMLElement {
  // Shared across all instances - the font is loaded once
  static _fontPromise = null;

  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
    this._raf = null;
    this._resizeObserver = null;
  }

  connectedCallback() {
    // Resolve font source: explicit src attribute, or the embedded base64
    var fontUrl = this.getAttribute('src')
      ? 'url(' + this.getAttribute('src') + ')'
      : 'url(data:font/woff2;base64,' + WALDEN_FONT + ')';

    // Shadow DOM - fully isolated from host page styles
    this.shadowRoot.innerHTML =
      '<style>' +
        '@font-face {' +
          'font-family: WaldenArizona;' +
          'src: ' + fontUrl + ' format("woff2");' +
          'font-display: block;' +
        '}' +
        ':host { display: inline-block; }' +
        '.logo {' +
          'font-family: WaldenArizona, sans-serif;' +
          'font-size: inherit;' +
          'line-height: 1;' +
          'white-space: nowrap;' +
          'font-kerning: normal;' +
          'color: inherit;' +
          'font-variation-settings: "wght" 443, "SRFF" 0.5;' +
          '-webkit-font-smoothing: antialiased;' +
          'display: flex;' +
          'align-items: baseline;' +
          'overflow: visible;' +
          'cursor: default;' +
        '}' +
        '.logo > div { flex-shrink: 0; overflow: visible; }' +
      '</style>' +
      '<div class="logo"></div>';

    this._logo = this.shadowRoot.querySelector('.logo');

    // Load font once into document.fonts (needed for ruler measurement).
    // All instances share a single promise - no redundant network requests.
    if (!WaldenLogo._fontPromise) {
      var font = new FontFace('WaldenArizona', fontUrl);
      document.fonts.add(font);
      WaldenLogo._fontPromise = font.load().catch(function() {});
    }

    WaldenLogo._fontPromise.then(() => this._build());
  }

  disconnectedCallback() {
    if (this._raf) cancelAnimationFrame(this._raf);
    if (this._resizeObserver) this._resizeObserver.disconnect();
  }

  _build() {
    var logo = this._logo;
    if (!logo) return;

    var chars = ['W', 'A', 'L', 'D', 'E', 'N'];
    var TRACKING = 0.24; // Brand letter-spacing in em

    // Measure glyph widths and kern pairs at the resting axis values
    // We append an off-screen ruler to document.body (not the shadow DOM)
    // so it can access the font loaded on document.fonts.
    var ruler = document.createElement('span');
    ruler.style.cssText =
      'position:fixed;top:-9999px;visibility:hidden;' +
      'font-family:WaldenArizona,sans-serif;font-size:100px;line-height:1;' +
      'font-variation-settings:"wght" 443,"SRFF" 0.5;' +
      'font-kerning:normal;white-space:nowrap';
    document.body.appendChild(ruler);

    // Individual glyph advances at the resting spec, in em units
    var widths = chars.map(function(c) {
      ruler.textContent = c;
      return ruler.getBoundingClientRect().width / 100;
    });

    // Kern pair adjustments: width("WA") - width("W") - width("A")
    // This captures the kern table value for each adjacent pair.
    var kerns = [];
    for (var i = 0; i < chars.length - 1; i++) {
      ruler.textContent = chars[i] + chars[i + 1];
      kerns.push(ruler.getBoundingClientRect().width / 100 - widths[i] - widths[i + 1]);
    }
    document.body.removeChild(ruler);

    // Build per-character slots
    // Each character sits in a fixed-width div so weight changes don't
    // cause adjacent letters to shift. margin-right = tracking + kern.
    chars.forEach(function(c, i) {
      var slot = document.createElement('div');
      slot.style.width = widths[i] + 'em';
      if (i < chars.length - 1) slot.style.marginRight = (TRACKING + kerns[i]) + 'em';
      slot.textContent = c;
      logo.appendChild(slot);
    });

    // Total logotype width in em (for width-mode font-size calculation)
    var totalEm = 0;
    for (var i = 0; i < widths.length; i++) totalEm += widths[i];
    for (var i = 0; i < kerns.length; i++) totalEm += kerns[i];
    totalEm += (chars.length - 1) * TRACKING;
    this._totalEm = totalEm;

    // Width mode
    // If a width attribute is set, calculate font-size to fill it exactly.
    this._applyWidth();

    // For responsive units (vw, %), recalculate on resize
    var widthAttr = this.getAttribute('width');
    if (widthAttr && /[%v]/.test(widthAttr)) {
      var self = this;
      this._resizeObserver = new ResizeObserver(function() { self._applyWidth(); });
      this._resizeObserver.observe(document.documentElement);
    }

    // Animation
    // Skip entirely if the user prefers reduced motion
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

    // Phase offsets so oscillation starts at the resting values (wght 443, SRFF 0.5)
    var W_PHASE = Math.asin((443 - 450) / 250);
    var S_PHASE = Math.asin(0.25);

    // Irrational period ratio (sqrt2) ensures the two axes never sync -
    // the combination of weight and serif is always unique.
    var W_PERIOD = 17000;
    var S_PERIOD = W_PERIOD * Math.SQRT2;

    // Constant-speed follower: current values chase the target (oscillation
    // or resting point) at a fixed rate, never snapping.
    var hovered = false, curW = 443, curS = 0.5, lastT = 0, startT = 0;
    logo.addEventListener('mouseenter', function() { hovered = true; });
    logo.addEventListener('mouseleave', function() { hovered = false; });

    var self = this;
    function tick(t) {
      if (!startT) startT = t;
      var elapsed = t - startT;
      var dt = lastT ? (t - lastT) / 1000 : 0;
      lastT = t;

      // Target: resting center on hover, oscillating sine waves otherwise
      var tW = hovered ? 443 : 450 + Math.sin(W_PHASE + elapsed * 2 * Math.PI / W_PERIOD) * 250;
      var tS = hovered ? 0.5 : 0.4 + Math.sin(S_PHASE + elapsed * 2 * Math.PI / S_PERIOD) * 0.4;

      // Move toward target at constant speed (units per second)
      curW += Math.sign(tW - curW) * Math.min(Math.abs(tW - curW), 160 * dt);
      curS += Math.sign(tS - curS) * Math.min(Math.abs(tS - curS), 0.3 * dt);

      logo.style.fontVariationSettings = '"wght" ' + curW + ', "SRFF" ' + curS;
      self._raf = requestAnimationFrame(tick);
    }
    this._raf = requestAnimationFrame(tick);
  }

  // Resolve the width attribute (any CSS unit) to pixels via a probe element,
  // then set font-size so the logotype fills that width exactly.
  _applyWidth() {
    var widthAttr = this.getAttribute('width');
    if (!widthAttr || !this._totalEm) return;

    var probe = document.createElement('div');
    probe.style.cssText = 'position:fixed;top:-9999px;width:' + widthAttr;
    (this.parentElement || document.body).appendChild(probe);
    var targetPx = probe.getBoundingClientRect().width;
    probe.remove();

    this._logo.style.fontSize = (targetPx / this._totalEm) + 'px';
  }
}

customElements.define('walden-logotype', WaldenLogo);
