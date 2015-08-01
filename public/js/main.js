$(function(){
  $('.add-star').click(function(){
    var $this = $(this)
    var post_id = $this.attr('data-post-id');
    $.ajax({
      url: '/vote/like/' + post_id,
      dataType: 'json',
      success: function(data){
        $this.text(data['voting_count']);
      },
      error: function(data){
        alert('失敗しました');
      }
    });
  });
});
