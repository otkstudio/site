// Theme Switching
(function () {
  const STORAGE_KEY = "marketing-theme";
  const THEMES = ["system", "light", "dark"];

  // Get stored theme preference or default to 'system'
  function getStoredTheme() {
    return localStorage.getItem(STORAGE_KEY) || "system";
  }

  // Get the actual theme to apply based on preference
  function getEffectiveTheme(preference) {
    if (preference === "system") {
      return window.matchMedia("(prefers-color-scheme: dark)").matches
        ? "dark"
        : "light";
    }
    return preference;
  }

  // Apply theme to document
  function applyTheme(theme) {
    const effectiveTheme = getEffectiveTheme(theme);
    document.documentElement.setAttribute("data-theme", effectiveTheme);
    document.documentElement.style.colorScheme = effectiveTheme;
  }

  // Update button states
  function updateButtonStates(activeTheme) {
    const buttons = document.querySelectorAll('[aria-label$="theme"]');
    const themeMap = {
      "System theme": "system",
      "Light theme": "light",
      "Dark theme": "dark",
    };

    // Find the pill indicator
    const pillContainer = document.querySelector(
      ".bg-theme-card-03-hex.rounded-full"
    );
    if (!pillContainer) return;

    const indicator = pillContainer.querySelector(".absolute.rounded-full");

    buttons.forEach((button, index) => {
      const buttonTheme = themeMap[button.getAttribute("aria-label")];
      const isActive = buttonTheme === activeTheme;

      if (isActive) {
        button.classList.remove("text-theme-text-sec");
        button.classList.add("text-theme-text");
        button.classList.remove("hover:text-theme-text");

        // Move the indicator
        if (indicator) {
          const buttonRect = button.getBoundingClientRect();
          const containerRect = pillContainer.getBoundingClientRect();
          const left = button.offsetLeft;
          indicator.style.left = `${left}px`;
          indicator.style.width = `${button.offsetWidth}px`;
        }
      } else {
        button.classList.add("text-theme-text-sec");
        button.classList.remove("text-theme-text");
        button.classList.add("hover:text-theme-text");
      }
    });
  }

  // Set theme and save preference
  function setTheme(theme) {
    localStorage.setItem(STORAGE_KEY, theme);
    applyTheme(theme);
    updateButtonStates(theme);
  }

  // Initialize
  function init() {
    const storedTheme = getStoredTheme();
    applyTheme(storedTheme);

    // Wait for DOM to be ready for button updates
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", () => {
        updateButtonStates(storedTheme);
        setupEventListeners();
      });
    } else {
      updateButtonStates(storedTheme);
      setupEventListeners();
    }
  }

  // Setup event listeners
  function setupEventListeners() {
    // Theme toggle buttons
    const buttons = document.querySelectorAll('[aria-label$="theme"]');
    buttons.forEach((button) => {
      button.addEventListener("click", () => {
        const label = button.getAttribute("aria-label");
        if (label === "System theme") setTheme("system");
        else if (label === "Light theme") setTheme("light");
        else if (label === "Dark theme") setTheme("dark");
      });
    });

    // Listen for system preference changes
    window
      .matchMedia("(prefers-color-scheme: dark)")
      .addEventListener("change", () => {
        const currentTheme = getStoredTheme();
        if (currentTheme === "system") {
          applyTheme("system");
        }
      });
  }

  // Run immediately to prevent flash
  init();
})();

// Timeline Image Preview
(function () {
  let preview = null;

  function createPreview() {
    preview = document.createElement('div');
    preview.className = 'timeline-preview';
    preview.innerHTML = '<img src="" alt="">';
    document.body.appendChild(preview);
    return preview;
  }

  function showPreview(e, imageUrl) {
    if (!preview) createPreview();
    const img = preview.querySelector('img');
    img.src = imageUrl;
    preview.classList.add('visible');
    updatePosition(e);
  }

  function hidePreview() {
    if (preview) {
      preview.classList.remove('visible');
    }
  }

  function updatePosition(e) {
    if (preview) {
      preview.style.left = e.clientX + 'px';
      preview.style.top = e.clientY + 'px';
    }
  }

  function init() {
    const links = document.querySelectorAll('[data-preview-image]');

    links.forEach(link => {
      link.addEventListener('mouseenter', (e) => {
        const imageUrl = link.getAttribute('data-preview-image');
        if (imageUrl) showPreview(e, imageUrl);
      });

      link.addEventListener('mousemove', updatePosition);

      link.addEventListener('mouseleave', hidePreview);
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();

// Timeline Opacity on Scroll
(function () {
  let timelineItems = [];
  let progressItems = [];
  let progressContainer = null;
  let centerY = 0;
  let ticking = false;
  let fixedImageContainer = null;
  let leftImage = null;
  let rightImage = null;
  let currentActiveItem = null;
  let scrollTimeout = null;
  let isScrolling = false;

  function calculateCenterY() {
    centerY = window.innerHeight / 2;
  }

  function getItemCenterY(item) {
    const rect = item.getBoundingClientRect();
    // Dot center is 12px from li top (6px offset + 6px half-height)
    return rect.top + 12;
  }

  function updateOpacity() {
    let closestItem = null;
    let closestIndex = -1;
    let closestDistance = Infinity;

    // Find the closest item to center
    timelineItems.forEach((item, index) => {
      const distance = Math.abs(getItemCenterY(item) - centerY);
      if (distance < closestDistance) {
        closestDistance = distance;
        closestItem = item;
        closestIndex = index;
      }
    });

    // Only activate if user has scrolled down
    if (window.scrollY <= 0) {
      closestItem = null;
      closestIndex = -1;
    }

    // Deactivate first item if user hasn't scrolled far enough or scrolled back up
    if (closestIndex === 0) {
      const firstItemRect = closestItem.getBoundingClientRect();
      // If the top of the first item is below where it would be when snapped, deactivate
      if (firstItemRect.top > centerY) {
        closestItem = null;
        closestIndex = -1;
      }
    }

    // Toggle active class on timeline items
    timelineItems.forEach((item) => {
      item.classList.toggle('timeline-item--active', item === closestItem);
    });

    // Update the fixed image display
    updateFixedImage(closestItem);

    // Toggle active class on progress items (progressItems excludes last timeline item)
    progressItems.forEach((item, index) => {
      item.classList.toggle('active', index === closestIndex);
      item.classList.toggle('adjacent', index === closestIndex - 1 || index === closestIndex + 1);
      item.classList.toggle('adjacent-2', index === closestIndex - 2 || index === closestIndex + 2);
    });

    // Check if scrolled past the "You" section (second-to-last item)
    const youSection = timelineItems[timelineItems.length - 2];
    const youRect = youSection?.getBoundingClientRect();
    const isPastYouSection = youRect && youRect.bottom < centerY;

    // Show/hide progress container (show from first section, hide when past You section)
    if (progressContainer) {
      progressContainer.classList.toggle('visible', closestItem !== null && closestIndex >= 0 && !isPastYouSection);
    }

    // Disable snap scrolling when past You section
    document.documentElement.classList.toggle('timeline-snap-disabled', isPastYouSection);

    ticking = false;
  }

  function hideImages() {
    if (fixedImageContainer) {
      leftImage.parentElement.classList.remove('visible');
      rightImage.parentElement.classList.remove('visible');
    }
  }

  function onScroll() {
    if (!ticking) {
      requestAnimationFrame(updateOpacity);
      ticking = true;
    }

    // Hide images while scrolling
    if (!isScrolling) {
      isScrolling = true;
      hideImages();
    }

    // Clear previous timeout
    clearTimeout(scrollTimeout);

    // Show images after scrolling stops
    scrollTimeout = setTimeout(() => {
      isScrolling = false;
      currentActiveItem = null; // Reset to force image update
      updateFixedImage(document.querySelector('.timeline-item--active'));
    }, 150);
  }

  function createFixedImageContainer() {
    fixedImageContainer = document.createElement('div');
    fixedImageContainer.className = 'timeline-fixed-images';

    // Left side image (for when text is on right)
    const leftSlot = document.createElement('div');
    leftSlot.className = 'timeline-fixed-image timeline-fixed-image--left';
    leftImage = document.createElement('img');
    leftImage.alt = '';
    leftSlot.appendChild(leftImage);

    // Right side image (for when text is on left)
    const rightSlot = document.createElement('div');
    rightSlot.className = 'timeline-fixed-image timeline-fixed-image--right';
    rightImage = document.createElement('img');
    rightImage.alt = '';
    rightSlot.appendChild(rightImage);

    fixedImageContainer.appendChild(leftSlot);
    fixedImageContainer.appendChild(rightSlot);
    document.body.appendChild(fixedImageContainer);
  }

  function updateFixedImage(activeItem) {
    if (!fixedImageContainer) return;

    // Only update if active item changed
    if (activeItem === currentActiveItem) return;
    currentActiveItem = activeItem;

    // Hide both
    leftImage.parentElement.classList.remove('visible');
    rightImage.parentElement.classList.remove('visible');

    if (!activeItem) return;

    const previewLink = activeItem.querySelector('[data-person-image]');
    if (!previewLink) return;

    const imageUrl = previewLink.getAttribute('data-person-image');
    const textDiv = activeItem.querySelector('[class*="text-right"], [class*="text-left"]');
    const isTextRight = textDiv?.classList.contains('text-right');

    if (isTextRight) {
      // Text is right, show image on right
      rightImage.src = imageUrl;
      rightImage.parentElement.classList.add('visible');
    } else {
      // Text is left, show image on left
      leftImage.src = imageUrl;
      leftImage.parentElement.classList.add('visible');
    }
  }

  function createProgressIndicator() {
    progressContainer = document.createElement('div');
    progressContainer.className = 'timeline-progress';

    timelineItems.forEach((item, index) => {
      // Skip the last item (empty spacer)
      if (index === timelineItems.length - 1) return;

      const yearEl = item.querySelector('.type-sm');
      const year = yearEl ? yearEl.textContent.trim() : '';

      const progressItem = document.createElement('button');
      progressItem.className = 'timeline-progress__item';
      progressItem.setAttribute('aria-label', `Scroll to ${year}`);
      progressItem.setAttribute('data-year', year);

      const bar = document.createElement('span');
      bar.className = 'timeline-progress__bar';

      progressItem.appendChild(bar);
      progressContainer.appendChild(progressItem);

      progressItem.addEventListener('click', () => {
        item.scrollIntoView({ behavior: 'smooth' });
      });

      progressItems.push(progressItem);
    });

    document.body.appendChild(progressContainer);
  }

  function init() {
    const container = document.querySelector('.timeline-container');
    if (!container) return;

    timelineItems = Array.from(container.querySelectorAll('ol > li'));
    if (timelineItems.length === 0) return;

    createFixedImageContainer();
    createProgressIndicator();
    calculateCenterY();
    updateOpacity();

    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', () => {
      calculateCenterY();
      updateOpacity();
    }, { passive: true });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();