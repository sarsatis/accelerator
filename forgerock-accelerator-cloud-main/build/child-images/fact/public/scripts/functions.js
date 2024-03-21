document.addEventListener("DOMContentLoaded", function(){
  // const btns = document.querySelectorAll('button.btn-with-spinner');
  // btns.forEach(btn => {
  //   btn.addEventListener('click', event => {
  //     btn.disabled = "true";
  //     btn.innerHTML = '<span class="spinner-border text-warning spinner-border-sm" role="status" aria-hidden="true"></span> Loading ...'
  //     btn.submit();
  //   });
  // });
  const btnActiveTab = document.querySelector("button[data-feature-selected='true']");
  if (btnActiveTab){
    btnActiveTab.click();
  }
});
function onSubmitForm(e){
  var submitBtns=e.target.querySelectorAll("[type='submit']");
  submitBtns.forEach(btn => {
    btn.disabled = "true";
    btn.classList.add("px-2");
    btn.innerHTML = btn.innerHTML + ' <span class="spinner-border text-warning spinner-border-sm" role="status" aria-hidden="true"></span>'
  });
  return true;
}