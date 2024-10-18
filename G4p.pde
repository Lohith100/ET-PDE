import g4p_controls.*;

import processing.serial.*;

import javax.swing.JOptionPane;

import java.awt.Font;



Serial myPort;

PFont pFont, placeholderFont;

Font awtFont;

StringBuilder buffer = new StringBuilder();



GDropList portList;

GButton refreshButton, applyButton, themeButton;

GTextArea receivedDataArea;

GTextField baudRateInput;



int buttonWidth = 160;

int buttonHeight = 100;



GButton offButton, laserOnButton, laserOffButton, autoButton, noDataButton;

GButton binaryButton, manualButton, sensorButton, energyButton, dataButton, dumpButton;



String binaryValue = "";

String manualValue = "";

String sensorValue = "";

String energyValue = "";

String dataValue = "";

String dumpValue = "";



GTextField binaryInput, manualInput, sensorInput, energyInput, dataInput, dumpInput;

GTextField focusedInput = null;



boolean isDumping = false;

PrintWriter output;

int lastDataReceivedTime = 0;

int dumpTimeout = 5000;



boolean newDataReceived = false;

boolean areaInitialized = false;



int defaultBaudRate = 115200;

boolean isDarkTheme = false;



int maxVisibleLines = 1200; // Keep a large buffer for scrolling, but limit active processing

int uiUpdateInterval = 100; // Update UI every 100 milliseconds

int lastUIUpdateTime = 0;



void setup() {

    size(1600, 900);

    surface.setResizable(true);

    G4P.setGlobalColorScheme(GCScheme.BLUE_SCHEME);



    portList = new GDropList(this, 50, 30, 200, 100, 5);

    portList.addEventHandler(this, "portListEvent");



    refreshPorts(); // Attempt to refresh ports at startup



    refreshButton = new GButton(this, 270, 30, 100, 20, "Refresh Ports");

    refreshButton.addEventHandler(this, "refreshPortsEvent");



    baudRateInput = new GTextField(this, 400, 30, 150, 20);

    baudRateInput.setText(str(defaultBaudRate));



    applyButton = new GButton(this, 400, 55, 100, 20, "Apply");

    applyButton.addEventHandler(this, "applySettingsEvent");



    themeButton = new GButton(this, 1200, 15, 100, 20, "Theme");

    themeButton.addEventHandler(this, "themeButtonEvent");



    pFont = createFont("Arial", 16, true);

    placeholderFont = createFont("Arial", 12, true);

    awtFont = new Font("Arial", Font.PLAIN, 16);



    offButton = new GButton(this, 50, 100, buttonWidth, buttonHeight, "Off");

    offButton.addEventHandler(this, "offButtonEvent");

    laserOnButton = new GButton(this, 220, 100, buttonWidth, buttonHeight, "Laser On");

    laserOnButton.addEventHandler(this, "laserOnButtonEvent");

    laserOffButton = new GButton(this, 390, 100, buttonWidth, buttonHeight, "Laser Off");

    laserOffButton.addEventHandler(this, "laserOffButtonEvent");

    autoButton = new GButton(this, 50, 520, buttonWidth, buttonHeight, "Auto");

    autoButton.addEventHandler(this, "autoButtonEvent");

    noDataButton = new GButton(this, 220, 520, buttonWidth, buttonHeight, "No Data");

    noDataButton.addEventHandler(this, "noDataButtonEvent");



    binaryButton = new GButton(this, 50, 230, buttonWidth, buttonHeight, "Binary\n (5cm-750cm)");

    binaryButton.addEventHandler(this, "binaryButtonEvent");

    manualButton = new GButton(this, 220, 230, buttonWidth, buttonHeight, "Manual\n (4cm-750cm)");

    manualButton.addEventHandler(this, "manualButtonEvent");

    sensorButton = new GButton(this, 390, 230, buttonWidth, buttonHeight, "Sensor\n (5cm-750cm)");

    sensorButton.addEventHandler(this, "sensorButtonEvent");

    energyButton = new GButton(this, 390, 380, buttonWidth, buttonHeight, "Energy\n (0-255)");

    energyButton.addEventHandler(this, "energyButtonEvent");

    dataButton = new GButton(this, 50, 380, buttonWidth, buttonHeight, "Data");

    dataButton.addEventHandler(this, "dataButtonEvent");

    dumpButton = new GButton(this, 220, 380, buttonWidth, buttonHeight, "Dump");

    dumpButton.addEventHandler(this, "dumpButtonEvent");



    binaryInput = new GTextField(this, 50, 350, 160, 20);

    binaryInput.setPromptText("Type Distance Here");

    manualInput = new GTextField(this, 220, 350, 160, 20);

    manualInput.setPromptText("Type Distance Here");

    sensorInput = new GTextField(this, 390, 350, 160, 20);

    sensorInput.setPromptText("Type Distance Here");

    dataInput = new GTextField(this, 50, 490, 160, 20);

    dataInput.setPromptText("Type File Name Here");

    dumpInput = new GTextField(this, 220, 490, 160, 20);

    dumpInput.setPromptText("Type File Name Here");

    energyInput = new GTextField(this, 390, 490, 160, 20);

    energyInput.setPromptText("Type Energy Here");



    receivedDataArea = new GTextArea(this, 560, 35, 800, 840, G4P.SCROLLBARS_VERTICAL_ONLY);

    receivedDataArea.setFont(awtFont);

    receivedDataArea.setTextEditEnabled(false);



    // Non-blocking thread to check port disconnection

    Thread portMonitorThread = new Thread(new Runnable() {

        public void run() {

            while (true) {

                monitorSerialPort();

                delay(500); // Check every 500ms to avoid overloading the CPU

            }

        }

    });

    portMonitorThread.start();



    // Start a separate thread for reading serial data

    Thread serialThread = new Thread(new Runnable() {

        public void run() {

            while (true) {

                if (myPort != null && myPort.available() > 0) {

                    serialEvent(myPort);

                }

                delay(10); // Small delay to prevent CPU overuse

            }

        }

    });

    serialThread.start();

}



void draw() {

    if (isDarkTheme) {

        background(50);

        fill(255);

    } else {

        background(240);

        fill(0);

    }

    textSize(25);

    text("Enactive Torch", 50, 80);



    text("Output from EnactiveTorch:", 560, 25);



    int textAreaWidth = width - 600;

    int textAreaHeight = height - 90;



    if (areaInitialized && (receivedDataArea.getWidth() != textAreaWidth || receivedDataArea.getHeight() != textAreaHeight)) {

        receivedDataArea.setVisible(false);

        receivedDataArea = new GTextArea(this, 560, 35, textAreaWidth, textAreaHeight, G4P.SCROLLBARS_VERTICAL_ONLY | G4P.SCROLLBARS_AUTOHIDE);

        receivedDataArea.setFont(awtFont);

        receivedDataArea.setTextEditEnabled(false);

    }

    areaInitialized = true;



    if (newDataReceived && millis() - lastUIUpdateTime > uiUpdateInterval) {

        synchronized(buffer) {

            receivedDataArea.setText(buffer.toString()); // Display full buffer, including old data

            // Move the caret to the end of the text area to auto-scroll

            int length = receivedDataArea.getText().length(); // Get the current length of the text

            receivedDataArea.moveCaretTo(length, length); // Move the caret to the end of the text

        }

        newDataReceived = false;

        lastUIUpdateTime = millis();

    }



    if (isDumping && millis() - lastDataReceivedTime > dumpTimeout) {

        stopDumping();

    }

}







// This function checks if the serial port has been disconnected or if it is not available

void monitorSerialPort() {

    if (myPort != null && !myPort.active()) {  // If the port is no longer active

        myPort.stop();

        myPort = null;

        synchronized(buffer) {

            buffer.append("[Warning] Serial port disconnected!\n");

        }

        newDataReceived = true; // Trigger UI update

    }

}



void serialEvent(Serial myPort) {

    try {

        String inData = myPort.readStringUntil('\n');

        if (inData != null) {

            synchronized(buffer) {

                buffer.append(inData.trim()).append("\n"); // Keep appending to the buffer

                if (buffer.length() > maxVisibleLines * 100) { // Approximate buffer size by characters

                    trimOldBufferData(); // Trim old data occasionally if buffer grows too large

                }

            }

            newDataReceived = true;

            if (isDumping) {

                output.println(inData.trim());

            }

            lastDataReceivedTime = millis();

        }

    } catch (Exception e) {

        // Handle exception

    }

}



void trimOldBufferData() {

    int excessLines = buffer.toString().split("\n").length - maxVisibleLines;

    if (excessLines > 0) {

        // Find the position of the excess lines to trim

        int trimIndex = 0;

        for (int i = 0; i < excessLines; i++) {

            trimIndex = buffer.indexOf("\n", trimIndex + 1);

        }

        buffer.delete(0, trimIndex + 1); // Remove old lines

    }

}



void startDumping(String fileName) {

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

}



public void portListEvent(GDropList list, GEvent event) {

    if (event == GEvent.SELECTED) {

        applySettings();

    }

}



void refreshPortsEvent(GButton button, GEvent event) {

    if (event == GEvent.CLICKED) {

        refreshPorts();

    }

}



void applySettingsEvent(GButton button, GEvent event) {

    if (event == GEvent.CLICKED) {

        applySettings();

    }

}



void offButtonEvent(GButton button, GEvent event) {

    if (event == GEvent.CLICKED) {

        sendCommand("off");

    }

}



void laserOnButtonEvent(GButton button, GEvent event) {

    if (event == GEvent.CLICKED) {

        sendCommand("laser_on");

    }

}



void laserOffButtonEvent(GButton button, GEvent event) {

    if (event == GEvent.CLICKED) {

        sendCommand("laser_off");

    }

}



void autoButtonEvent(GButton button, GEvent event) {

    if (event == GEvent.CLICKED) {

        sendCommand("auto");

    }

}



void noDataButtonEvent(GButton button, GEvent event) {

    if (event == GEvent.CLICKED) {

        sendCommand("nodata");

    }

}



void binaryButtonEvent(GButton button, GEvent event) {

    if (event == GEvent.CLICKED) {

        binaryValue = binaryInput.getText();

        if (isValidInput(binaryValue, 5, 750)) {

            sendCommand("binary" + binaryValue);

        } else {

            showError("Invalid binary input. Please enter a value between 5 and 750.");

        }

    }

}



void manualButtonEvent(GButton button, GEvent event) {

    if (event == GEvent.CLICKED) {

        manualValue = manualInput.getText();

        if (isValidInput(manualValue, 4, 750)) {

            sendCommand("manual" + manualValue);

        } else {

            showError("Invalid manual input. Please enter a value between 4 and 750.");

        }

    }

}



void sensorButtonEvent(GButton button, GEvent event) {

    if (event == GEvent.CLICKED) {

        sensorValue = sensorInput.getText();

        if (isValidInput(sensorValue, 5, 750)) {

            sendCommand("sensor" + sensorValue);

        } else {

            showError("Invalid sensor input. Please enter a value between 5 and 750.");

        }

    }

}



void energyButtonEvent(GButton button, GEvent event) {

    if (event == GEvent.CLICKED) {

        energyValue = energyInput.getText();

        if (energyValue.equals("")) {

            sendCommand("energy0");

        } else if (isValidInput(energyValue, 0, 255)) {

            sendCommand("energy" + energyValue);

        } else {

            showError("Invalid energy input. Please enter a value between 0 and 255.");

        }

    }

}



void dataButtonEvent(GButton button, GEvent event) {

    if (event == GEvent.CLICKED) {

        dataValue = dataInput.getText();

        if (isValidFileName(dataValue)) {

            sendCommand("data" + dataValue);

        } else {

            showError("Invalid data input. Please enter a valid file name.");

        }

    }

}



void dumpButtonEvent(GButton button, GEvent event) {

    if (event == GEvent.CLICKED) {

        dumpValue = dumpInput.getText();

        if (isValidFileName(dumpValue)) {

            sendCommand("dump" + dumpValue);

            startDumping(dumpValue);

        } else {

            showError("Invalid dump input. Please enter a valid file name.");

        }

    }

}



void refreshPorts() {

    // Check for available ports and handle gracefully if no ports are found

    String[] ports = Serial.list();

    if (ports.length > 0) {

        portList.setItems(ports, 0); // Populate dropdown with available ports

    } else {

        portList.setItems(new String[] { "No ports available" }, 0); // Show warning in dropdown

        JOptionPane.showMessageDialog(null, "No serial ports available. Please connect a device and refresh.", "Port Error", JOptionPane.WARNING_MESSAGE);

    }

}



void applySettings() {

    // Stop previous serial port if necessary

    if (portList != null && portList.getSelectedIndex() >= 0) {

        String selectedPort = portList.getSelectedText();

        if (!selectedPort.equals("No ports available")) {

            int baudRate = int(baudRateInput.getText());

            if (myPort != null) {

                myPort.stop();

            }

            delay(100);

            try {

                myPort = new Serial(this, selectedPort, baudRate);

                JOptionPane.showMessageDialog(null, "Serial port connected: " + selectedPort, "Success", JOptionPane.INFORMATION_MESSAGE);

            } catch (Exception e) {

                JOptionPane.showMessageDialog(null, "Failed to open the selected port. It might be busy or unavailable.", "Port Error", JOptionPane.ERROR_MESSAGE);

            }

        }

    } else {

        JOptionPane.showMessageDialog(null, "Please select a valid serial port.", "Port Error", JOptionPane.WARNING_MESSAGE);

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



void sendCommand(String command) {

    if (myPort != null) {

        myPort.write(command + "\n");

    }

}



void themeButtonEvent(GButton button, GEvent event) {

    if (event == GEvent.CLICKED) {

        isDarkTheme = !isDarkTheme;

    }

}
