library test;

import 'dart:math';
import 'dart:html';
import 'dart:async';

part 'touch.dart';
WebSocket ws;

outputMsg(String msg) {

  print(msg);

}

//standard websocket setup
void initWebSocket([int retrySeconds = 2]) {
  var reconnectScheduled = false;

  outputMsg("Connecting to websocket");
  ws = new WebSocket('ws://127.0.0.1:4040/ws');

  void scheduleReconnect() {
    if (!reconnectScheduled) {
      new Timer(new Duration(milliseconds: 1000 * retrySeconds), () => initWebSocket(retrySeconds * 2));
    }
    reconnectScheduled = true;
  }

  ws.onOpen.listen((e) {
    outputMsg('Connected');
    ws.send('connected');
  });

  ws.onClose.listen((e) {
    outputMsg('Websocket closed, retrying in $retrySeconds seconds');
    scheduleReconnect();
  });

  ws.onError.listen((e) {
    outputMsg("Error connecting to ws");
    scheduleReconnect();
  });

  ws.onMessage.listen((MessageEvent e) {
      game.handleMsg(e.data);
//    outputMsg('Received message: ${e.data}');
  });
}


//make the game.
var game;

void main() {

  print("started");
  initWebSocket();
  game = new Game();

}

void repaint() {
  game.draw();
}

var imageWidth;
var imageHeight;


//object class, unlike server, this one is touchable but otherwise has the same properties
class Box implements Touchable{
  num x;
  num y;
  var color;
  num id;
  bool dragged;
  int imageWidth;
  int imageHeight;
  
  int width;
  int height;
  
  ImageElement img = new ImageElement();
  
  Box rightBuddy = null;
  Box leftBuddy = null;
  Box upperBuddy = null;
  Box lowerBuddy = null;
  Box leftNeighbor = null;
  Box rightNeighbor = null;
  Box upperNeighbor = null;
  Box lowerNeighbor = null;
  
  
  Timer dragTimer;

  Box(this.id, this.x, this.y, this.color){
    //tmanager.registerEvents(this);
    //document.onMouseUp.listen((e) => myTouchUp(e));
    //document.onTouchEnd.listen((e) => touchUp(e));
    dragged= false;
    img.src = "images/${this.color}.png";
    imageWidth=img.width;
    imageHeight=img.height;
  }

  //when this object is dragged, send a 'd' message with id, x, y, color
  sendDrag(num newX, num newY){

    if (rightNeighbor != null && leftNeighbor != null){
      ws.send("d:${id},${newX},${newY},${color},${leftNeighbor.color},${rightNeighbor.color}, Client#${game.clientID}");
    }
    else {
      ws.send("d:${id},${newX},${newY},${color}, Client#${game.clientID}");
    }
    //
    }


  bool containsTouch(Contact e) {
    if((e.touchX > x && e.touchX  < x +100) && 
      (e.touchY > y && e.touchY < y + 100)){
        return true;
      }
    return false;
  }

  bool touchDown(Contact e) {
    dragged = true;
    //dragTimer = new Timer.periodic(const Duration(milliseconds : 80), (timer) => sendDrag(e.touchX, e.touchY));
//    print(e.touchX);
    return true;
  }
//
//  bool myTouchDown(MouseEvent event) {
//    dragged = true;
//    ws.send("c:${id}, ${color}, ${game.clientID}");
//    //dragTimer = new Timer.periodic(const Duration(milliseconds : 80), (timer) => sendDrag(event.touchX, e.touchY));
////    print(e.touchX);
//    return true;
//  }

  void touchUp(Contact event) {
    dragged = false;
    try{
          //dragTimer.cancel();
    }
    catch(exception){
          print(exception);
    }
    pieceLocation();
    ws.send("b:${id}, ${color}, ${game.clientID}");
    //print("touchup ${id}");
  }

  //this is same as touchUp but the touch.dart doesn't seem have an error in touchUp
//  void myTouchUp(MouseEvent event) {
//    print('touchup');
//    try{
//      //dragTimer.cancel();
//    }
//    catch(exception){
//      print(exception);
//    }
//    dragged = false;
//    pieceLocation();
//    ws.send("b:${id}, ${color}, ${game.clientID}");
////    print("touchup ${id}");
//  }

  void touchDrag(Contact e) {
    //print('touchdrag');
    //since touchUp has issues it impacts touchDrag so have extra bool to makes sure this are being dragged
    if(dragged){
      sendDrag(e.touchX, e.touchY);
      //print(e.touchX);
    }
  }

  void touchSlide(Contact event) { }



  void pieceLocation (){
    Box box=this;
    imageWidth=box.img.width;
    imageHeight=box.img.height;
      //When the boxes touch each other
      //assign the Neighbors according to the predetermined pattern.
      if (box.rightBuddy != null &&box.rightNeighbor==null){
        if (box.rightBuddy.x + 10 + imageWidth >= box.x &&
            box.rightBuddy.y + 10 + imageHeight >= box.y &&
            box.rightBuddy.x + 10  <= box.x + imageWidth + 20 &&
            box.rightBuddy.y + 10  <= box.y + 20 + imageHeight){
           box.rightNeighbor = box.rightBuddy;
           box.rightBuddy.leftNeighbor = box;
           print ('rightneighbors!');
           ws.send("n:${box.id},right,${box.rightNeighbor.id}");
        }
      }
      if (box.leftBuddy != null && box.leftNeighbor==null){
        if (box.leftBuddy.x + 10 + imageWidth >= box.x &&
            box.leftBuddy.y + 10 + imageHeight >= box.y &&
            box.leftBuddy.x + 10  <= box.x + 20 + imageWidth &&
            box.leftBuddy.y + 10  <= box.y + 20 + imageHeight){
           box.leftNeighbor = box.leftBuddy;
           box.leftBuddy.rightNeighbor = box;
           print ('left neighbors!');
           ws.send("n:${box.id},left,${box.leftNeighbor.id}");
        }
      }
      if (box.upperBuddy != null && box.upperNeighbor==null){
        if (box.upperBuddy.x + 10 + imageWidth >= box.x &&
            box.upperBuddy.y + 10 + imageHeight >= box.y &&
            box.upperBuddy.x + 10 <= box.x + 20 + imageWidth &&
            box.upperBuddy.y + 10 <= box.y + 20 + imageHeight){
           box.upperNeighbor = box.upperBuddy;
           box.upperBuddy.lowerNeighbor = box;
           print ('upper neighbors!');
           ws.send("n:${box.id},upper,${box.upperNeighbor.id}");
        }
      }
      if (box.lowerBuddy != null && box.lowerNeighbor==null){
        if (box.lowerBuddy.x + 10 + imageWidth >= box.x &&
            box.lowerBuddy.y + 10 + imageHeight >= box.y &&
            box.lowerBuddy.x + 10 <= box.x + 20 + imageWidth &&
            box.lowerBuddy.y + 10 <= box.y + 20 + imageHeight){
           box.lowerNeighbor = box.lowerBuddy;
           box.lowerBuddy.upperNeighbor = box;
           print ('lower neighbors!');
           ws.send("n:${box.id},lower,${box.lowerNeighbor.id}");
        }
      }
    }



  
  void draw(CanvasRenderingContext2D ctx){
    ctx.save();
    {
    num boxWidth = img.width;
    num boxHeight = img.height;
    ctx.translate(x, y);
//    ctx.fillStyle = 'yellow';
//    ctx.fillRect(x, y, 50, 50);
    ctx.drawImage(img, 0, 0);
    }
    ctx.restore();
  }

}


//client state class, doesn't need update or send state, just need to keep track of objects via updateBox()
class State{
  Game boxGame;
  List<Box> myBoxes;
  //TouchLayer tlayer;
  int lastLength=0;
  State(game){
    boxGame = game;
    myBoxes = new List<Box>();
  }

  addBox(Box newBox){
    myBoxes.add(newBox);
  }

  updateState(){


  }

  sendState(){


  }

  updateBox(num id, num x, num y, String color){
    bool found = false;
    int myBoxesLength=myBoxes.length;

    int myBoxesLengthSqrt=sqrt(myBoxesLength).toInt();
    if (myBoxesLengthSqrt*myBoxesLengthSqrt!=myBoxesLength){
      //print ("EXIT, NOT A SQUARE");
      //return;
    }
    for(Box box in myBoxes){
      if(id == box.id){
        box.x = x;
        box.y = y;
        box.color = color;
        found = true;
        //lastLength!=myBoxesLength
        if (true){
          int i = myBoxes.indexOf(box);
                  if (i % myBoxesLengthSqrt== 0){
                    box.rightBuddy = myBoxes[i + 1];
                  }
                  else if (i % myBoxesLengthSqrt == myBoxesLengthSqrt - 1){
                    box.leftBuddy = myBoxes[i - 1];
                  }
                  else {
                    box.leftBuddy = myBoxes[i - 1];
                    box.rightBuddy = myBoxes[i + 1];
                  }
                  if (i/myBoxesLengthSqrt<1){
                    box.lowerBuddy= myBoxes[i+myBoxesLengthSqrt];
                  }
                  else if (i/myBoxesLengthSqrt>=myBoxesLengthSqrt-1){
                    box.upperBuddy= myBoxes[i-myBoxesLengthSqrt];
                  }
                  else{
                    box.lowerBuddy= myBoxes[i+myBoxesLengthSqrt];
                    box.upperBuddy= myBoxes[i-myBoxesLengthSqrt];
                  }
        }
      }
    }

    //if new box, create new object and add to touchables
    if(found == false){
      Box temp = new Box(id, x, y, color);
      temp.width = 50;
      temp.height = 50;
      boxGame.touchables.add(temp);
      myBoxes.add(temp);
    }
    lastLength=myBoxesLength;

  }



}


//client game class, allows us to draw images and create touch layers.
class Game extends TouchLayer{


  // this is the HTML canvas element
  CanvasElement canvas;

  ImageElement img = new ImageElement();

  // this object is what you use to draw on the canvas
  CanvasRenderingContext2D ctx;


  // width and height of the canvas
  int width, height;

  State myState;
  Box box;

  TouchManager tmanager = new TouchManager();
  TouchLayer tlayer = new TouchLayer();

  var score;
  var phaseBreak;
  var clientID;
  var trialNum;
  bool flagDraw = true;

  Game() {
    canvas = querySelector("#game");
    ctx = canvas.getContext('2d');
    width = canvas.width;
    height = canvas.height;

    
    //tmanager.registerEvents(document.documentElement);
    tmanager.registerEvents(document.documentElement);
    tmanager.addTouchLayer(this);
    
    myState = new State(this);


    // redraw the canvas every 40 milliseconds runs animate function every 40 milliseconds
    //updating at 15fps for now, will test for lag at 30 fps later
    //new Timer.periodic(const Duration(milliseconds : 80), (timer) => animate());

    window.animationFrame.then(animate);

  }


//**
// * Animate all of the game objects makes things movie without an event
// */
  void animate(double i) {
    window.animationFrame.then(animate);
    //print("time spent on listen");
//    ws.onMessage.listen((MessageEvent e) {
//      //print (e.data);
//      handleMsg(e.data);
//    });
    //print("time spent on draw");
    draw();

  }


//**
// * Draws programming blocks
// */
  void draw() {
    if (flagDraw){
      //print ('drawing');
      clear();
      //ctx.clearRect(0, 0, width, height);
      if (phaseBreak == 'false'){
        ctx.fillStyle = 'white';
        ctx.font = '30px sans-serif';
        ctx.textAlign = 'left';
        ctx.textBaseline = 'center';
        ctx.fillText("Server/Client Attempt: Client# ${clientID} Trial# ${trialNum}", 100, 50);
        ctx.fillText("Score: ${score}", 100, 100);
        for(Box box in myState.myBoxes){
          box.draw(ctx);
          //ctx.fillStyle = box.color;
          //ctx.fillRect(box.x, box.y, 50, 50);
        }
      flagDraw = false;
      }
      if (phaseBreak == 'true'){
        ctx.fillStyle = 'white';
        ctx.font = '30px sans-serif';
        ctx.textAlign = 'left';
        ctx.textBaseline = 'center';
        ctx.fillText("10 second break!", 100, 50);
      }
    }
  }

  void clear(){
    ctx.save();
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, width, height);
    ctx.restore();
  }

  //parse incoming messages
  handleMsg(data){
    flagDraw = true;
    //print (data);
    //'u' message indicates a state update
    if(data[0] == "u"){
      //split up the message via each object
      List<String> objectsData = data.substring(2).split(";");
      for(String object in objectsData){
        //parse each object data and pass to state.
        List<String> data = object.split(",");
        if(data.length > 3){
          myState.updateBox(num.parse(data[0]), num.parse(data[1]), num.parse(data[2]), data[3]);
          //pieceLocation();
        }
      }
    }
    if (data[0] == "s"){
      score = data.substring(2);
    }
    if (data[0] == "p"){
         phaseBreak = data.substring(2);
    }
    if (data[0] == "i"){
      String tempMsg = data.substring(2);
      List<String> temp = tempMsg.split(",");
      clientID = temp[0];
      trialNum = temp[1];
    }
  }
}
