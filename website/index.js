$(document).ready(function (e) {
    $win = $(window);
    $navbar = $('#header');
    $toggle = $('.toggle-button');
    var width = $navbar.width();
    toggle_onclick($win, $navbar, width);

    // resize event
    $win.resize(function () {
        toggle_onclick($win, $navbar, width);
    });

    $toggle.click(function (e) {
        $navbar.toggleClass("toggle-left");
    })

});

function toggle_onclick($win, $navbar, width) {
    if ($win.width() <= 768) {
        $navbar.css({ left: `-${width}px` });
    } else {
        $navbar.css({ left: '0px' });
    }
}

var typed = new Typed('#typed', {
    strings: [
        'Cloud Engineer',
        'Cloud Architect',
        'DevOps Engineer',
        'AWS SSA, MCSE, VCP'
    ],
    typeSpeed: 50,
    backSpeed: 50,
    loop: true
});

var typed_2 = new Typed('#typed_2', {
    strings: [
        'Cloud Engineer',
        'Cloud Architect',
        'DevOps Engineer'
    ],
    typeSpeed: 50,
    backSpeed: 50,
    loop: true
});

document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();

        document.querySelector(this.getAttribute('href')).scrollIntoView({
            behavior: 'smooth'
        });
    });
});

const counter = document.querySelector(".counter-number");
async function updateCounter() {
    let response = await fetch("https://hrq2m63cqjmza2ppjxnongxsqy0ddosm.lambda-url.us-east-2.on.aws/");
    let data = await response.json();
    counter.innerHTML = `👀 Views: ${data}`;
}
updateCounter();

// New Counter from GPT
/*
const globalCounter = document.querySelector(".counter-number");
const localCounter = document.getElementById("counterValue");

async function updateGlobalCounter() {
    let response = await fetch("https://111oukdrjhj4x5aeoiahmyxxe0jqgsv.lambda-url.us-east-1.on.aws/");
    let data = await response.json();
    globalCounter.innerHTML = `👀 Views: ${data}`;
}

async function updateLocalCounter() {
    let response = await fetch("https://your-new-counter-endpoint"); // Replace with your new counter endpoint
    let data = await response.json();
    localCounter.innerHTML = `Local Views: ${data}`;
}

// Call the update functions
updateGlobalCounter();
updateLocalCounter();
*/
// End New Counter from GPT

var mySwiper = new Swiper('.swiper-container', {
    // параметры
    direction: 'vertical', // прокручивание вертикально
    slidesPerView: 'auto', // автоматическое определение количества видимых слайдов
    freeMode: true, // включить свободный режим (плавное прокручивание)
    mousewheel: true, // включить прокрутку колесом мыши
});
