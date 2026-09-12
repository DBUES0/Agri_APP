const form = document.getElementById('marcajeForm');
const btnFichar = document.getElementById('btnFichar');

form.addEventListener('submit', function(e) {
    e.preventDefault();
    btnFichar.disabled = true;
    btnFichar.innerText = 'Obteniendo ubicación...';

    if (navigator.geolocation) {
        navigator.geolocation.getCurrentPosition(
            (position) => {
                document.getElementById('lat').value = position.coords.latitude;
                document.getElementById('lon').value = position.coords.longitude;
                form.submit();
            },
            (error) => {
                form.submit();
            }
        );
    } else {
        form.submit();
    }
});