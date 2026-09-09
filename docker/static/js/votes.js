(function () {
  'use strict';

  document.addEventListener('click', function (event) {
    var button = event.target.closest('.postVote');
    if (!button || button.disabled) {
      return;
    }

    var controls = button.closest('.postVotes');
    if (!controls) {
      return;
    }

    var board = location.pathname.split('/').filter(Boolean)[0];
    var body = new FormData();
    body.append('mode', 'vote');
    body.append('no', controls.getAttribute('data-no'));
    body.append('dir', button.getAttribute('data-dir'));

    Array.prototype.forEach.call(controls.querySelectorAll('button'), function (item) {
      item.disabled = true;
    });

    fetch('/' + encodeURIComponent(board) + '/post', {
      method: 'POST',
      body: body,
      credentials: 'same-origin',
      headers: { Accept: 'application/json' }
    }).then(function (response) {
      return response.json().then(function (payload) {
        if (!response.ok) {
          throw new Error(payload.error || 'Vote failed');
        }
        return payload;
      });
    }).then(function (payload) {
      Array.prototype.forEach.call(
        document.querySelectorAll('.postVotes[data-no="' + payload.no + '"]'),
        function (item) {
          item.querySelector('.upvoteCount').textContent = payload.upvotes;
          item.querySelector('.downvoteCount').textContent = payload.downvotes;
          item.setAttribute('data-vote', payload.direction);
        }
      );
    }).catch(function (error) {
      window.alert(error.message);
    }).finally(function () {
      Array.prototype.forEach.call(controls.querySelectorAll('button'), function (item) {
        item.disabled = false;
      });
    });
  });
}());
