extension ListExtenstion on List{
  bool equals(List list){
    if(length != list.length){
      return false;
    }
    for(int i = 0; i < length; i++){
      if(this[i] != list[i]){
        return false;
      }
    }
    return true;
  }
}