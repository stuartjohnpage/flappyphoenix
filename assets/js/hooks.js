let Hooks = {};

// Move updateViewport to module scope
const updateViewport = function(hook) {
  const viewportHeight = window.innerHeight;
  const viewportWidth = window.innerWidth;
  const zoomLevel = window.devicePixelRatio;

  hook.pushEvent("resize", {
    height: viewportHeight,
    width: viewportWidth,
    zoom: zoomLevel
  });
};

Hooks.ResizeHook = {
  mounted() {
    // Create bound handler that can be removed later
    this.boundUpdateViewport = () => updateViewport(this);
    
    window.addEventListener("resize", this.boundUpdateViewport);
    this.boundUpdateViewport(); // Call initially
  },
  
  destroyed() {
    window.removeEventListener("resize", this.boundUpdateViewport);
  }
};

export default Hooks;
