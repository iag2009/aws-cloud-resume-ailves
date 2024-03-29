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
        'AWS SAP, MCSE, VCP'
    ],
    typeSpeed: 50,
    backSpeed: 50,
    loop: true
});

var typed_2 = new Typed('#typed_2', {
    strings: [
        '&nbsp;Cloud Engineer',
        '&nbsp;Cloud Architect',
        '&nbsp;DevOps Engineer'
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
    try {
        let response = await fetch("https://wwwzmykydj4ad2ki5axcp3luxi0altoz.lambda-url.us-east-2.on.aws/");
        let data = await response.json();
        counter.innerHTML = `👀 Views: ${data.views}`;
    } catch (error) {
        console.error('Error:', error);
    }
}
updateCounter();

var mySwiper = new Swiper('.swiper-container', {
    //direction: 'vertical', // прокручивание вертикально
    //slidesPerView: 'auto', // автоматическое определение количества видимых слайдов
    //freeMode: true, // включить свободный режим (плавное прокручивание)
    //freeModeSticky: true, // make swiper stick to positions after you release it
    //mousewheel: true, // включить прокрутку колесом мыши
    //mousewheel: {
    //    releaseOnEdges: true, // передать прокрутку мыши родительскому элементу, если достигнуты края слайдера
    //},
});
