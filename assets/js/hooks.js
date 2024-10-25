let Hooks = {};

Hooks.ResizeHook = {
  mounted() {
    // Call this function initially and whenever the window is resized
    const updateViewport = () => {
      const viewportHeight = window.innerHeight;
      const viewportWidth = window.innerWidth;
      const zoomLevel = window.devicePixelRatio

      console.log(zoomLevel)

      // Push new values to LiveView
      this.pushEvent("resize", {
        height: viewportHeight,
        width: viewportWidth,
        zoom: zoomLevel
      });
    };

    // Detect viewport resize
    window.addEventListener("resize", updateViewport);
    updateViewport(); // Call initially to send the current values
  },
  
  destroyed() {
    window.removeEventListener("resize", updateViewport);
  }
};

export default Hooks;