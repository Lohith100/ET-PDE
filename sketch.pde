import processing.serial.*;
import controlP5.*;
import javax.swing.JOptionPane;
import javax.swing.JFileChooser;
import java.io.File;

Serial myPort;
PFont font, placeholderFont;
StringBuilder buffer = new StringBuilder();
StringBuilder dumpBuffer = new StringBuilder();

ControlP5 cp5;
DropdownList portList;
controlP5.Button refreshButton, applyButton;
Textarea receivedDataArea;
TextInput baudRateInput;

int buttonWidth = 160;
int buttonHeight = 100;

Button offButton, laserOnButton, laserOffButton, autoButton, noDataButton;
Button binaryButton, manualButton, sensorButton, energyButton, dataButton, dumpButton;
Button scrollTopButton, scrollBottomButton;

String binaryValue = "";
String manualValue = "";
String sensorValue = "";
String energyValue = "";
String dataValue = "";
String dumpValue = "";

TextInput binaryInput, manualInput, sensorInput, energyInput, dataInput, dumpInput;
TextInput focusedInput = null;

boolean isDumping = false;
PrintWriter output;
int lastDataReceivedTime = 0;
int dumpTimeout = 5000;


final int MAX_CHARACTERS = 1_000_000;
final int MAX_LINES = 10000;

void setup() {
  size(1600, 900);
  cp5 = new ControlP5(this);

  portList = cp5.addDropdownList("portList")
                .setPosition(50, 30)
                .setSize(200, 100)
                .setBarHeight(20)
                .setItemHeight(20)
                .onChange(new CallbackListener() {
                  public void controlEvent(CallbackEvent event) {
                    applySettings();
                  }
                });

  refreshPorts();

  refreshButton = cp5.addButton("refreshPorts")
                     .setPosition(270, 30)
                     .setSize(100, 20)
                     .setLabel("Refresh Ports")
                     .onClick(new CallbackListener() {
                       public void controlEvent(CallbackEvent event) {
                         refreshPorts();
                       }
                     });

  baudRateInput = new TextInput(600, 30, 150, 20, "Enter Baud Rate");
  baudRateInput.inputText = "115200";

  applyButton = cp5.addButton("applySettings")
                   .setPosition(600, 55)
                   .setSize(100, 20)
                   .setLabel("Apply")
                   .onClick(new CallbackListener() {
                     public void controlEvent(CallbackEvent event) {
                       applySettings();
                     }
                   });

  font = createFont("Arial", 16, true);
  placeholderFont = createFont("Arial", 12, true);
  textFont(font);

  offButton = new Button(50, 100, buttonWidth, buttonHeight, "Off", "off");
  laserOnButton = new Button(220, 100, buttonWidth, buttonHeight, "Laser On", "laser_on");
  laserOffButton = new Button(390, 100, buttonWidth, buttonHeight, "Laser Off", "laser_off");
  autoButton = new Button(560, 100, buttonWidth, buttonHeight, "Auto", "auto");
  noDataButton = new Button(390, 380, buttonWidth, buttonHeight, "No Data", "nodata");

  binaryButton = new Button(50, 230, buttonWidth, buttonHeight, "Binary\n (5cm-750cm)", "binary");
  manualButton = new Button(220, 230, buttonWidth, buttonHeight, "Manual\n (4cm-750cm)", "manual");
  sensorButton = new Button(390, 230, buttonWidth, buttonHeight, "Sensor\n (5cm-750cm)", "sensor");
  energyButton = new Button(560, 230, buttonWidth, buttonHeight, "Energy\n (0-255)", "energy");
  dataButton = new Button(50, 380, buttonWidth, buttonHeight, "Data", "data");
  dumpButton = new Button(220, 380, buttonWidth, buttonHeight, "Dump", "dump");

  binaryInput = new TextInput(50, 350, 160, 20, "Type Distance Here");
  manualInput = new TextInput(220, 350, 160, 20, "Type Distance Here");
  sensorInput = new TextInput(390, 350, 160, 20, "Type Distance Here");
  energyInput = new TextInput(560, 350, 160, 20, "Type Energy Here");
  dataInput = new TextInput(50, 490, 160, 20, "Type File Name Here");
  dumpInput = new TextInput(220, 490, 160, 20, "Type File Name Here");

  scrollTopButton = new Button(1555, 35, 40, 40, "↑", "scrollTop");
  scrollBottomButton = new Button(1555, 835, 40, 40, "↓", "scrollBottom");

  receivedDataArea = cp5.addTextarea("receivedDataArea")
                        .setPosition(755, 35)
                        .setSize(800, 840)
                        .setFont(createFont("Arial", 12))
                        .setLineHeight(14)
                        .setColor(color(0))
                        .setColorBackground(color(255))
                        .setColorForeground(color(173, 216, 230));


}

void draw() {
  background(240);

  fill(0);
  textSize(25);
  text("Enactive Torch", 460, 50);

  offButton.display();
  laserOnButton.display();
  laserOffButton.display();
  autoButton.display();
  noDataButton.display();

  binaryButton.display();
  manualButton.display();
  sensorButton.display();
  energyButton.display();
  dataButton.display();
  dumpButton.display();

  binaryInput.display();
  manualInput.display();
  sensorInput.display();
  energyInput.display();
  dataInput.display();
  dumpInput.display();
  baudRateInput.display();

  scrollTopButton.display();
  scrollBottomButton.display();

  fill(0);
  text("Output from EnactiveTorch:", 855, 25);
  fill(255);
  rect(755, 35, 800, 840, 10);

  receivedDataArea.setText(buffer.toString());



  // Autoscroll to the bottom
  if (receivedDataArea.getText().length() > 0) {
    receivedDataArea.scroll(receivedDataArea.getText().length());
  }

  // Handle dumping status
  if (isDumping && millis() - lastDataReceivedTime > dumpTimeout) {
    stopDumping();
  }

  if (isDumping) {
    fill(0);
    textSize(25);
    textAlign(LEFT, BOTTOM);
    text("Dumping file: " + dumpValue, 10, height - 30);
    int dotCount = (frameCount / 30) % 4;
    String dots = "";
    for (int i = 0; i < dotCount; i++) {
      dots += ".";
    }
    text(dots, 200, height - 30);
  }
}

void serialEvent(Serial myPort) {
  byte[] inData = new byte[1024];
  int len = myPort.readBytesUntil('\n', inData);

  if (len > 0) {
    String data = new String(inData, 0, len);
    buffer.append(data + "\n");
    truncateLines();
    if (isDumping) {
      dumpBuffer.append(data + "\n");
    }
    lastDataReceivedTime = millis();
    if (isDumping && output != null) {
      output.println(data);
    }
  }
}

void truncateLines() {
  String[] lines = buffer.toString().split("\n");
  if (lines.length > MAX_LINES) {
    buffer = new StringBuilder();
    for (int i = lines.length - MAX_LINES; i < lines.length; i++) {
      buffer.append(lines[i]).append("\n");
    }
  }
  if (buffer.length() > MAX_CHARACTERS) {
    buffer.delete(0, buffer.length() - MAX_CHARACTERS);
  }
}

void startDumping(String fileName) {
  dumpBuffer.setLength(0);
  output = createWriter(fileName);
  isDumping = true;
  lastDataReceivedTime = millis();
}

void stopDumping() {
  if (output != null) {
    output.flush();
    output.close();
    output = null;
  }
  isDumping = false;

  JFileChooser fileChooser = new JFileChooser();
  fileChooser.setDialogTitle("Save Dump File");
  int userSelection = fileChooser.showSaveDialog(null);
  if (userSelection == JFileChooser.APPROVE_OPTION) {
    File fileToSave = fileChooser.getSelectedFile();
    saveStrings(fileToSave.getAbsolutePath(), dumpBuffer.toString().split("\n"));
    JOptionPane.showMessageDialog(null, "File saved: " + fileToSave.getAbsolutePath(), "File Saved", JOptionPane.INFORMATION_MESSAGE);
  }
}

void mousePressed() {
  if (offButton.isMouseOver()) offButton.sendCommand();
  if (laserOnButton.isMouseOver()) laserOnButton.sendCommand();
  if (laserOffButton.isMouseOver()) laserOffButton.sendCommand();
  if (autoButton.isMouseOver()) autoButton.sendCommand();
  if (noDataButton.isMouseOver()) noDataButton.sendCommand();

  if (binaryButton.isMouseOver()) {
    binaryValue = binaryInput.getText();
    if (isValidInput(binaryValue, 5, 750)) {
      binaryButton.sendCommand(binaryValue);
    } else {
      showError("Invalid binary input. Please enter a value between 5 and 750.");
    }
  }
  if (manualButton.isMouseOver()) {
    manualValue = manualInput.getText();
    if (isValidInput(manualValue, 4, 750)) {
      manualButton.sendCommand(manualValue);
    } else {
      showError("Invalid manual input. Please enter a value between 4 and 750.");
    }
  }
  if (sensorButton.isMouseOver()) {
    sensorValue = sensorInput.getText();
    if (isValidInput(sensorValue, 5, 750)) {
      sensorButton.sendCommand(sensorValue);
    } else {
      showError("Invalid sensor input. Please enter a value between 5 and 750.");
    }
  }
  if (energyButton.isMouseOver()) {
    energyValue = energyInput.getText();
    if (energyValue.equals("") || energyValue.equals("0")) {
      energyButton.sendCommand("0");
    } else if (isValidInput(energyValue, 0, 255)) {
      energyButton.sendCommand(energyValue);
    } else {
      showError("Invalid energy input. Please enter a value between 0 and 255.");
    }
  }
  if (dataButton.isMouseOver()) {
    dataValue = dataInput.getText();
    if (isValidFileName(dataValue)) {
      dataButton.sendCommand(dataValue);
    } else {
      showError("Invalid data input. Please enter a valid file name.");
    }
  }
  if (dumpButton.isMouseOver()) {
    dumpValue = dumpInput.getText();
    if (isValidFileName(dumpValue)) {
      dumpButton.sendCommand(dumpValue);
      startDumping(dumpValue);
    } else {
      showError("Invalid dump input. Please enter a valid file name.");
    }
  }
  if (scrollTopButton.isMouseOver()) {
    receivedDataArea.scroll(0);
  }
  if (scrollBottomButton.isMouseOver()) {
    receivedDataArea.scroll(receivedDataArea.getText().length());
  }
  if (receivedDataArea.getText().length() > 0) {
    receivedDataArea.scroll(receivedDataArea.getText().length());
  }

  if (binaryInput.isMouseOver()) focusedInput = binaryInput;
  else if (manualInput.isMouseOver()) focusedInput = manualInput;
  else if (sensorInput.isMouseOver()) focusedInput = sensorInput;
  else if (energyInput.isMouseOver()) focusedInput = energyInput;
  else if (dataInput.isMouseOver()) focusedInput = dataInput;
  else if (dumpInput.isMouseOver()) focusedInput = dumpInput;
  else if (baudRateInput.isMouseOver()) {
    focusedInput = baudRateInput;
    baudRateInput.inputText = "";
  } else focusedInput = null;

  binaryInput.setFocus(binaryInput == focusedInput);
  manualInput.setFocus(manualInput == focusedInput);
  sensorInput.setFocus(sensorInput == focusedInput);
  energyInput.setFocus(energyInput == focusedInput);
  dataInput.setFocus(dataInput == focusedInput);
  dumpInput.setFocus(dumpInput == focusedInput);
  baudRateInput.setFocus(baudRateInput == focusedInput);
}



class Button {
  int x, y, w, h;
  String label, command;

  Button(int x, int y, int w, int h, String label, String command) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.label = label;
    this.command = command;
  }

  void display() {
    fill(#fbe4d6);
    rect(x, y, w, h, 10);
    fill(0);
    textAlign(CENTER, CENTER);
    text(label, x + w / 2, y + h / 2);
  }

  boolean isMouseOver() {
    return mouseX > x && mouseX < x + w && mouseY > y && mouseY < y + h;
  }

  void sendCommand() {
    if (myPort != null) {
      myPort.write(command + "\n");
    }
  }

  void sendCommand(String input) {
    if (myPort != null) {
      String fullCommand = command + input;
      myPort.write(fullCommand + "\n");
    }
  }
}

class TextInput {
  int x, y, w, h;
  String inputText = "";
  String placeholder;
  boolean isFocused = false;

  TextInput(int x, int y, int w, int h, String placeholder) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.placeholder = placeholder;
  }

  void display() {
    if (isFocused) {
      stroke(0, 0, 255);
    } else {
      stroke(0);
    }
    fill(255);
    rect(x, y, w, h, 5);
    fill(0);
    textAlign(LEFT, CENTER);
    textSize(12);
    if (inputText.length() > 0 || isFocused) {
      text(inputText, x + 5, y + h / 2);
    } else {
      fill(150);
      text(placeholder, x + 5, y + h / 2);
    }
    textSize(16);
  }

  void keyPressed(char key) {
    if (key == BACKSPACE && inputText.length() > 0) {
      inputText = inputText.substring(0, inputText.length() - 1);
    } else if (key != BACKSPACE && key != ENTER && key != RETURN) {
      inputText += key;
    }
  }

  String getText() {
    return inputText;
  }

  boolean isMouseOver() {
    return mouseX > x && mouseX < x + w && mouseY > y && mouseY < y + h;
  }

  void setFocus(boolean focus) {
    isFocused = focus;
  }
}

void keyPressed() {
  if (focusedInput != null) {
    focusedInput.keyPressed(key);
  }
}

void refreshPorts() {
  if (portList != null) {
    portList.clear();
    String[] ports = Serial.list();
    if (ports.length > 0) {
      portList.addItems(ports);
    } else {
      JOptionPane.showMessageDialog(null, "No serial ports available.", "Port Error", JOptionPane.ERROR_MESSAGE);
    }
  }
}

void applySettings() {
  if (portList != null && portList.getItems().size() > 0 && portList.getValue() >= 0) {
    String selectedPort = portList.getItem((int)portList.getValue()).get("name").toString();
    int baudRate = int(baudRateInput.getText());
    if (myPort != null) {
      myPort.stop();
    }
    delay(100);
    try {
      myPort = new Serial(this, selectedPort, baudRate);
    } catch (Exception e) {
      JOptionPane.showMessageDialog(null, "The selected port is already in use or busy.", "Port Error", JOptionPane.ERROR_MESSAGE);
    }
  } else {
    JOptionPane.showMessageDialog(null, "Please select a valid serial port.", "Port Error", JOptionPane.ERROR_MESSAGE);
  }
}

boolean isValidInput(String input, int minValue, int maxValue) {
  try {
    int value = int(input);
    return value >= minValue && value <= maxValue;
  } catch (NumberFormatException e) {
    return false;
  }
}

boolean isValidFileName(String fileName) {
  return fileName.matches("^[a-zA-Z0-9._-]+$");
}

void showError(String message) {
  JOptionPane.showMessageDialog(null, message, "Input Error", JOptionPane.ERROR_MESSAGE);
}
