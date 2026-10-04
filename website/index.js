// Loaded with `defer`, so the DOM is ready and typed.min.js has already run.
//
// jQuery and Swiper are gone: jQuery 3.4.1 drove only the mobile menu toggle
// (whose button no longer existed), and Swiper wrapped the page without a
// single slide. Navigation is now pure CSS (style.css), smooth scrolling is
// `scroll-behavior: smooth`.

// autoInsertCss: false — typed.js would otherwise inject a <style> element,
// which the Content-Security-Policy blocks. The cursor CSS lives in style.css.
new Typed('#typed', {
    strings: [
        'Senior DevOps Engineer',
        'Agentic Platform Engineer',
        'Cloud Architect',
        'Kubernetes & EKS Engineer',
        'AWS Solutions Architect – Professional'
    ],
    typeSpeed: 50,
    backSpeed: 30,
    backDelay: 1500,
    loop: true,
    autoInsertCss: false
});

// View counter. The Lambda Function URL reads the count on GET and increments
// it on POST (envs/dev/lambda/func.py.tftpl). The first page load of a browser
// session counts the visit; reloads in the same session only read it.
const COUNTER_API = "https://wwwzmykydj4ad2ki5axcp3luxi0altoz.lambda-url.us-east-2.on.aws/";
const COUNTED_KEY = "viewCounted";

// sessionStorage throws in some privacy modes; then every load counts.
function alreadyCounted() {
    try {
        return sessionStorage.getItem(COUNTED_KEY) === "1";
    } catch (e) {
        return false;
    }
}

function markCounted() {
    try {
        sessionStorage.setItem(COUNTED_KEY, "1");
    } catch (e) {
        // nothing to do
    }
}

async function updateCounter() {
    const counter = document.querySelector(".counter-number");
    const value = document.getElementById("counterValue");
    if (!counter || !value) {
        return;
    }

    const count = !alreadyCounted();
    try {
        const response = await fetch(COUNTER_API, { method: count ? "POST" : "GET" });
        if (!response.ok) {
            throw new Error(`counter API returned ${response.status}`);
        }
        const data = await response.json();
        if (count) {
            markCounted();
        }
        value.textContent = data.views;
    } catch (error) {
        console.error('Error:', error);
        // The counter is decoration, not content: hide it rather than show a
        // placeholder forever.
        counter.hidden = true;
    }
}
updateCounter();
