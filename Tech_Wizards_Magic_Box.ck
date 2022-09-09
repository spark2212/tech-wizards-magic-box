// ///////////////////////////////////////////////////////
// Tech Wizard's Magic Box
// Date: 5/14/2021 
// Author: Theodore Shore
//
// This design was somewhat inspired by a theremin.
// It uses a wii remote to control pitch and 
// sound on/off, the keyboard to select oscillators,
// and the mouse to control panning and gain.
//
// Code pulled from wiimote_theremin.ck, by Ming-Lun Lee
// ///////////////////////////////////////////////////////

Envelope env[3];
Gain g[3];
Pan2 p[3];

SinOsc a => g[0] => p[0] => env[0] => dac;
BlitSquare s => g[1] => p[1] => env[1] => dac;
BlitSaw d => g[2] => p[2] => env[2] => dac;

a.gain(1.0);
s.gain(0.15);
d.gain(0.1);

[0, 0, 0] @=> int key_positions[]; // positions of the A, S, and D keys
[0, 0, 0] @=> int freq_shift[]; // whether or not to shift the frequency down
                                // by a perfect fifth
                                
0 => int wii_position; // position of the A button on the wiimote
                                
0 => int mouse_dev; // mouse HID device number
0 => int kb_dev; // keyboard HID device number

// hid objects
Hid mouse;
HidMsg mouse_msg;

Hid kb;
HidMsg kb_msg;

// try
if(!mouse.openMouse(mouse_dev))
{
    <<< "* Could not open mouse. Goodbye!", "" >>>;
    me.exit();
}
<<< "* mouse ready...", "" >>>;

if(!kb.openKeyboard(kb_dev))
{
    <<< "* Could not open keyboard. Goodbye!", "" >>>;
    me.exit();
}
<<< "* keyboard ready...", "" >>>;

fun void set_pan_and_volume()
{
    while(true)
    {
        // wait
        mouse => now;
        
        while(mouse.recv(mouse_msg))
        {
            if(mouse_msg.isMouseMotion())
            {
                for(0 => int i; i < 3; i++)
                {
                    if(Std.fabs(mouse_msg.deltaX) > 3 * Std.fabs(mouse_msg.deltaY))
                        Math.min(8 * mouse_msg.scaledCursorX - 1, 1) => p[i].pan;
                    if(Std.fabs(mouse_msg.deltaY) > 3 * Std.fabs(mouse_msg.deltaX))
                        Math.pow(1.0 - mouse_msg.scaledCursorY, 2) => g[i].gain;
                }
                    
                //<<< "pan == ", p[0].pan() >>>;
                //<<< "gain == ", g[0].gain() >>>;
            }
        }
    }
}

0 => int kb_changed;

fun void set_key_positions()
{
    while(true)
    {
        kb => now;
        // 4 == A, 22 == S, 7 == D
        // 29 == Z, 27 == X, 6 == C
        while(kb.recv(kb_msg))
        {
            <<< kb_msg.which >>>;
            
            
            // if button is down, corresponding oscillator becomes playable
            if(kb_msg.isButtonDown())
            {
                [0, 0, 0] @=> int kb_changes[];
                if(kb_msg.which == 4 || kb_msg.which == 29)
                    1 => key_positions[0] => kb_changes[0];
                else if(kb_msg.which == 22 || kb_msg.which == 27)
                    1 => key_positions[1] => kb_changes[1];
                else if(kb_msg.which == 7 || kb_msg.which == 6)
                    1 => key_positions[2] => kb_changes[2];
                
                if(kb_msg.which == 29)
                    1 => freq_shift[0];
                else if(kb_msg.which == 27)
                    1 => freq_shift[1];
                else if(kb_msg.which == 6)
                    1 => freq_shift[2];
                else if(kb_msg.which == 4)
                    0 => freq_shift[0];
                else if(kb_msg.which == 22)
                    0 => freq_shift[1];
                else if(kb_msg.which == 7)
                    0 => freq_shift[2];
                
                1 => kb_changed;
                if(kb_changed && wii_position)
                {
                    for(0 => int i; i < 3; i++)
                    {
                        // if a new keyboard button is held down while
                        // the wiimote A button is being held, turn on
                        // the corresponding envelope.
                        if(kb_changes[i])
                            env[i].keyOn(1);
                    }
                }
            }
            else if(kb_msg.isButtonUp()) // corresponding oscillator becomes unplayable
            {
                [1, 1, 1] @=> int kb_changes[];
                if((kb_msg.which == 4 && freq_shift[0] == 0) 
                  || (kb_msg.which == 29 && freq_shift[0] == 1))
                    0 => key_positions[0] => kb_changes[0];
                else if((kb_msg.which == 22 && freq_shift[1] == 0) 
                       || (kb_msg.which == 27 && freq_shift[1] == 1))
                    0 => key_positions[1] => kb_changes[1];
                else if((kb_msg.which == 7 && freq_shift[2] == 0) 
                       || (kb_msg.which == 6 && freq_shift[2] == 1))
                    0 => key_positions[2] => kb_changes[2];
                
                1 => kb_changed;
                if(kb_changed)
                {
                    for(0 => int i; i < 3; i++)
                    {
                        1 - kb_changes[i] => kb_changes[i];
                        
                        // if a new keyboard button is released, turn
                        // off the corresponding envelope.
                        if(kb_changes[i])
                            env[i].keyOff(1);
                    }
                }
            } 
             
            for(0 => int i; i < 3; i++)
                <<< "key_positions[", i, "] == ", key_positions[i] >>>;  
        }
    }
}



OscRecv recv;
6449 => recv.port;

recv.listen();
recv.event("/wii/1/accel/pry/0, f") @=> OscEvent ePitch;
recv.event("/wii/1/button/A, f") @=> OscEvent eOnOff;

60 => int midiNoteCenter;
60.0 => float midi_note;

// reads the wiimote pitch and converts to a corresponding frequency
// for the Oscillators
// from wiimote_theremin.ck (in-class demo project)
fun void set_pitches(OscEvent evnt) {
    while(true)
    {
        evnt => now;
        while(evnt.nextMsg() != 0)
        {
            evnt.getFloat() => float p;
            //<<< "Pitch = ", p >>>;
            midiNoteCenter + (p - 0.5) * 48 => midi_note;
            
            Std.mtof(midi_note - 5 * freq_shift[0]) => a.freq;
            Std.mtof(midi_note - 5 * freq_shift[1]) => s.freq;
            Std.mtof(midi_note - 5 * freq_shift[2]) => d.freq;
            //Std.mtof(midiNoteCenter + (p - 0.5) * 48) => freq;
        }
    } 
}

/*fun void set_pitch()
{
    while(true)
        1;//<<< wiimote.pitch() >>>;
}*/

// controls keyOn and keyOff of the envelopes
fun void play_notes(OscEvent evnt)
{
    0 => int on_off;
    [0, 0, 0] @=> int key_on[]; 
    
    while(true)
    {
        evnt => now; 
        while(evnt.nextMsg() != 0 || kb_changed == 1)
        {
            evnt.getFloat() => float my_float;
            if(my_float != on_off || kb_changed == 1)
            {
                my_float $ int => on_off => wii_position;         
                <<< "on_off == ", on_off >>>;
                
                for(0 => int i; i < 3; i++)
                {
                    <<< "key_positions[", i, "] == ", key_positions[i] >>>; 
                    if(on_off && key_positions[i] == 1 && key_on[i] != 1)
                        1 => key_on[i] => env[i].keyOn;
                    else if(key_on[i] > on_off || key_on[i] > key_positions[i])
                    {
                        0 => key_on[i];
                        1 => env[i].keyOff;
                        //env[i].keyOn(0);
                    }
                }
            }
            
            0 => kb_changed;
        }
    }
}

// spork shreds and advance time
spork ~ set_pan_and_volume();
spork ~ set_key_positions();
spork ~ set_pitches(ePitch);
spork ~ play_notes(eOnOff);

while(true)
    second => now;