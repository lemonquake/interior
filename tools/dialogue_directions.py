"""0.60: the acting directions for every voiced line: ElevenLabs v4 audio tags ([whispers], [voice breaking]...) and
punctuation for timing. Keyed by the line's text (speaker-independent, so a survivor's line reads the same for all).
No accent directions of any kind (owner's rule). Run: python -I tools/dialogue_directions.py  (writes 'tts' into
game/assets/audio/voices/dialogue.json; then tools/dialogue_lines.py keeps them on regeneration).
"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATH = os.path.join(ROOT, 'game', 'assets', 'audio', 'voices', 'dialogue.json')

D = {
    # Jonna: hiding in the mart's back office, cut by fridge glass, shaking, relieved, guilty, then urgent.
    "Salamat sa Diyos. You're real. When the shooting stopped I prayed it was you out there and not them.":
        "[shaky, close to tears] Salamat sa Diyos... you're real. [exhales] When the shooting stopped, I prayed it was you out there... and not them.",
    "Three nights ago it was only the news. A fight at Bankerohan market, people biting. By morning the barangay was ringing the bell and nobody knew why.":
        "[tired, haunted] Three nights ago, it was only the news. A fight at Bankerohan market... people biting. By morning the barangay was ringing the bell, and nobody knew why.",
    "Then it was everywhere at once. The ambulances stopped coming. The soldiers came in yesterday and made the mart their supply point. They held that door all night.":
        "Then it was everywhere. At once. The ambulances stopped coming. The soldiers came in yesterday, made the mart their supply point... [quietly] They held that door all night.",
    "When the front glass went they pushed the customers to the back. I got this door shut. The others... I heard them. I could not open it.":
        "When the front glass went, they pushed the customers to the back. I got this door shut. The others... [voice breaking] I heard them. I could not open it.",
    "Leave it. It's the fridge glass, not a bite. I tied it off. If I stand too long the room turns, that's all.":
        "[pained, waving it off] Leave it. It's the fridge glass, not a bite! I tied it off. If I stand too long, the room turns... that's all.",
    "Listen to me. That radio on the desk. Last night someone came on the barangay channel, a teacher. There are survivors at the college up north, the Prof. Ivan Lawrence College, five hundred metres from here. The gates are shut. They have water and a generator.":
        "[urgent] Listen to me. That radio, on the desk. Last night someone came on the barangay channel... a teacher. There are survivors at the college up north, the Prof. Ivan Lawrence College. Five hundred metres from here. The gates are shut. They have water, and a generator.",
    "No. The main road is finished. Cars on top of cars, fires, and them, hundreds of them. You won't drive it and you won't walk it.":
        "[firmly] No. No! The main road is finished. Cars on top of cars, fires... and them. Hundreds of them. You won't drive it, and you won't walk it.",
    "Go out the back. The service gate opens on the old backstreets behind the shops: the pawnshop, the bakery, the Avenida arcade. They're narrow, but they run all the way to the school's back gate.":
        "Go out the back. The service gate opens on the old backstreets behind the shops. The pawnshop, the bakery, the Avenida arcade. They're narrow... but they run all the way to the school's back gate.",
    "I would slow you down and you know it. Lock this door behind you. If the radio comes back I'll tell them you're coming. Go, before the night gets any older.":
        "[sad smile] I would slow you down, and you know it. Lock this door behind you. If the radio comes back, I'll tell them you're coming. [softly] Go... before the night gets any older.",
    "Pssst! Hoy! Here, the office! Quick, before more of them come!":
        "[loud whisper, frantic] Pssst! Hoy! Here! The office! Quick, before more of them come!",
    "Take it. The service gate key. Lock my door behind you. Go.":
        "[pressing it into your hand] Take it. The service gate key. Lock my door behind you. [urgent] Go.",
    "Wait. Let me shut the front first. The light draws them.":
        "[nervous] Wait, wait. Let me shut the front first. The light draws them.",
    "There. Nothing comes through that now.":
        "[out of breath, relieved] There. Nothing comes through that now.",
    # Rommel: the night guard at the college gate, bitten, exhausted, ashamed, holding on.
    "You came through the backstreets? Diyos ko... I thought the whole city was gone.":
        "[stunned, weak] You came through the backstreets? Diyos ko... [shaky laugh] I thought the whole city was gone.",
    "Rommel. Night guard. Eleven years on this gate. Sir Ivan hired me himself.":
        "[tired, a little proud] Rommel. Night guard. Eleven years on this gate. Sir Ivan hired me himself.",
    "When it started he told me: nobody in, nobody out, until the ambulances come. So I locked it. I locked it with four thousand kids inside.":
        "When it started, he told me: nobody in, nobody out, until the ambulances come. So I locked it. [voice breaking] I locked it... with four thousand kids inside.",
    "The fifth floor. Last night a light came on in a classroom up there, west side. Someone flashed it three times. They're waiting for someone.":
        "[looking up, hopeful] The fifth floor. Last night a light came on in a classroom up there, west side. Someone flashed it. Three times. They're waiting for someone.",
    "I tried to go up. The kids piled their desks into the stairs to stop the others following them. Only one way is open from each floor. You'll have to cross every floor to find it.":
        "[frustrated] I tried to go up. The kids piled their desks into the stairs, to stop the others following them. Only one way is open from each floor. You'll have to cross every floor to find it.",
    "He went up after them the first night, with a fire extinguisher and his keys. He never came down.":
        "[quietly, grieving] He went up after them the first night... with a fire extinguisher and his keys. [pause] He never came down.",
    "They're not sick anymore, the students. They're fast, and they don't stop. Don't let them follow you up the stairs.":
        "[grim warning] They're not sick anymore, the students. They're fast. And they don't stop. Don't let them follow you up the stairs.",
    "Look at my arm. You know what this is. I'll hold the gate behind you for as long as I'm still me. Please. Bring those children out.":
        "[bitter laugh] Look at my arm. You know what this is. [steady] I'll hold the gate behind you... for as long as I'm still me. [pleading] Please. Bring those children out.",
    "Hoy... hoy! Over here, by the gate! Don't shoot... I'm not one of them!":
        "[hoarse, desperate] Hoy... hoy! Over here, by the gate! Don't shoot! [panicked] I'm not one of them!",
    "It's open. The main doors are at the end of the covered walk. Fifth floor, west side. Go!":
        "[straining, urgent] It's open! The main doors are at the end of the covered walk. Fifth floor, west side. Go!",
    "I've got the gate. Go! Don't wait for me!":
        "[shouting over the noise] I've got the gate! Go! Don't wait for me!",
    # Ma'am Teves: the teacher in 501, holding five children together; terrified, firm, whispering.
    "Diyos ko... you're real. You're not from the barangay. Who sent you?":
        "[trembling, disbelieving] Diyos ko... you're real. [wary] You're not from the barangay. Who sent you?",
    "That was me. Three times, every night. Eleven of us came up here the first night. Some went down to find their parents. Five of us are left.":
        "That was me. Three times, every night. Eleven of us came up here the first night. Some went down to find their parents. [voice cracking] Five of us are left.",
    "Bea, Paolo, Jerome, Trisha. Up. Get your bags. These people are taking us out.":
        "[firm teacher's voice] Bea, Paolo, Jerome, Trisha. Up! Get your bags. These people are taking us out.",
    "He brought us water on the second night, through the ceiling. He went back down for the others. We heard him on the stairs. Then we didn't.":
        "[sadly] He brought us water on the second night, through the ceiling. He went back down for the others. We heard him on the stairs. [long pause] Then we didn't.",
    "Listen to me. At this hour they come through. All of them. Up the east stairs and along this hall, every night, like the bell still rings for them.":
        "[urgent, low] Listen to me. At this hour, they come through. All of them. Up the east stairs and along this hall, every night... like the bell still rings for them.",
    "Every light off. Everyone inside, away from the door, and nobody moves until they've gone past. Not a sound. Please.":
        "Every light off. Everyone inside, away from the door, and nobody moves until they've gone past. Not a sound. [begging] Please.",
    "They've stopped. They won't go now. Not until it's light.":
        "[whispers, afraid] They've stopped. They won't go now... Not until it's light.",
    "Hear that, in the ceiling? They're in the vent. The way you came is full of them.":
        "[whispers] Hear that? In the ceiling? [shaky whisper] They're in the vent. The way you came is full of them.",
    "The fire exit, at the far end of this hall. We chained it ourselves the first night. Here, the key. Slowly. Lights off. If anyone fires, all of them come.":
        "[whispers] The fire exit, at the far end of this hall. We chained it ourselves, the first night. Here... the key. Slowly. Lights off. [tense whisper] If anyone fires, all of them come.",
    "Diyos ko... Mang Dado? That's Mang Dado. He kept this gate. He locked it every night at nine.":
        "[horrified] Diyos ko... Mang Dado? [voice breaking] That's Mang Dado. He kept this gate. He locked it every night, at nine.",
    "The key... the gate's key is on his lanyard. It's still round his neck.":
        "[realizing, quietly] The key... the gate's key is on his lanyard. It's still round his neck.",
    "Inside. Lights off. Here they come.":
        "[whispers urgently] Inside. Lights off. Here they come.",
    "Inside! Now! I can hear them on the stairs!":
        "[panicked whisper] Inside! Now! I can hear them on the stairs!",
    "That's the east stairs. Don't. Move.":
        "[barely a whisper] That's the east stairs. Don't. Move.",
    "The gas! The kitchen's gas store! Hold on to something!":
        "[screaming] The gas! The kitchen's gas store! Hold on to something!",
    "It's down... it's over. The key, there, on the ground. Take it, open the gate!":
        "[breathless, shaking] It's down... it's over. [urgent] The key! There, on the ground. Take it, open the gate!",
    # Paolo, a student, panicking.
    "Ma'am, look: the stairs are gone! There's smoke coming out of 208... the wall's gone, there's a roof under it!":
        "[panicked, shouting] Ma'am, look, the stairs are gone! There's smoke coming out of two-oh-eight... the wall's gone! There's a roof under it!",
    # Dodong Sikma: bitten, old, wants to go home; weak and pleading, then urging them on.
    "I'm bitten. Please, I just want to go home. The soldiers went to the Olivar mart. None came back, but their equipment is still there. Stay with me.":
        "[pained, weak] I'm bitten. Please... I just want to go home. The soldiers went to the Olivar mart. None came back... but their equipment is still there. [pleading] Stay with me.",
    "This is my house. I used to keep watch for the neighbourhood. My keys are beside the candle.":
        "[tired relief] This is my house. I used to keep watch for the neighbourhood. My keys are beside the candle.",
    "This is my house. My keys are beside the candle.":
        "[tired relief] This is my house. My keys are beside the candle.",
    "Those are my gate keys. Leave me here. Take the north walk to the bridge, then the ramp. Go quietly up there. Hurry!":
        "[weakly] Those are my gate keys. Leave me here. [coughs] Take the north walk to the bridge, then the ramp. Go quietly up there. [urgent] Hurry!",
    "The roof fell in. Hold C and follow me under. The plank bridge is just ahead.":
        "[whispers, strained] The roof fell in. Crouch, and follow me under. The plank bridge is just ahead.",
    # The hooded man: out of breath, urgent, then kind, then frantic.
    "You have to hurry!": "[out of breath, urgent] You have to hurry!",
    "Your wife and 2 daughters are with the association, so you can breathe easy.":
        "[calmer, reassuring] Your wife and two daughters are with the association... so you can breathe easy.",
    "Now, I have to give you something. Please follow me.":
        "[serious] Now... I have to give you something. Please, follow me.",
    "Now, take these with you and go back! Hurry, before they notice!":
        "[frantic] Now, take these with you and go back! Hurry, before they notice!",
    # The player on his own (single player): low, wary, talking to himself.
    "Hello? ...Nobody.": "[calling softly] Hello?... [uneasy] Nobody.",
    "Padlocked. From the outside.": "[quietly, uneasy] Padlocked. From the outside.",
    "Something moved in there. Or I imagined it.": "[tense whisper] Something moved in there. [nervous breath] Or I imagined it.",
    "It smells like something died behind this door.": "[disgusted, gagging] It smells like something died behind this door.",
    "Locked. A wet rag is stuffed under it.": "Locked. [puzzled] A wet rag is stuffed under it.",
    "Someone sprayed a number on it. A census mark... or a warning.": "Someone sprayed a number on it. A census mark... [ominous] or a warning.",
    "I can hear dripping inside.": "[whispers] I can hear dripping inside.",
    "Locked. Good.": "[relieved exhale] Locked. Good.",
    "I guess no one's home..": "[sighs] I guess no one's home...",
    "Hello? ...Anyone there?": "[calling out, hesitant] Hello?... [quieter] Anyone there?",
    "Locked. No answer, either.": "Locked. [uneasy] No answer, either.",
    "Someone used to live here. Where did everybody go?": "[sad, quiet] Someone used to live here. Where did everybody go?",
    "I thought I heard something inside.": "[nervous whisper] I thought I heard something inside.",
    "No lights. Not a sound.": "[quietly] No lights. Not a sound.",
    "Maybe I should leave this one alone.": "[uneasy] Maybe I should leave this one alone.",
    "Shit..": "[shocked, under his breath] Shit...",
    "I thought this place was empty decades ago?": "[disturbed] I thought this place was empty... decades ago?",
    "Chained shut.": "[frustrated] Chained shut.",
    "That padlock is new.": "[suspicious] That padlock is new.",
    "Someone comes down here.": "[ominous whisper] Someone comes down here.",
    "I've never been inside of the Nichols property..": "[nervous, hushed] I've never been inside of the Nichols property...",
    "It's.. locked? Weird.": "[confused] It's... locked? [puzzled] Weird.",
    "The roof's caved in. I'll have to crouch to get under.": "[grunts] The roof's caved in. I'll have to crouch to get under.",
    # Narration (Lemon Voice): low, grave, storyteller.
    "Dodong didn't make it home.": "[grave, quiet] Dodong didn't make it home.",
    "The whole team is down.": "[grave] The whole team is down.",
    "The back door gives way!": "[tense] The back door gives way!",
    "Both stairs up are piled with desks. Someone wrote on the wall: FIRE EXIT, EAST END.":
        "[low, ominous] Both stairs up are piled with desks. Someone wrote on the wall... Fire exit. East end.",
    "Both stairs are blocked again. A note says the janitor's ladder goes up.":
        "[low] Both stairs are blocked again. A note says... the janitor's ladder goes up.",
    "Somewhere down this corridor someone is knocking. Three times, then nothing.":
        "[hushed, eerie] Somewhere down this corridor, someone is knocking. Three times... [pause] then nothing.",
    "The desks behind the door scrape aside. A teacher in a maroon blazer, and four students behind her.":
        "[hushed] The desks behind the door scrape aside. A teacher in a maroon blazer... and four students behind her.",
    "The chain slides off the push bar. Cold air. The fire escape goes all the way down.":
        "[quiet tension] The chain slides off the push bar. Cold air. The fire escape goes all the way down.",
    "The field. The blast brought them all out here, and they've heard you. The rear gate is at the far end.":
        "[grave, urgent] The field. The blast brought them all out here... and they've heard you. The rear gate is at the far end.",
    "The padlock opens; the chain rattles down. The gate swings out onto the street.":
        "[relief, quiet] The padlock opens... the chain rattles down. The gate swings out onto the street.",
    # Survivors' own story lines (said by whichever survivor talked).
    "You're hurt. What happened here?": "[concerned] You're hurt. What happened here?",
    "Let me look at that.": "[gently] Let me look at that.",
    "Then we take the main road. It runs straight there.": "Then we take the main road. It runs straight there.",
    "Come with us.": "[pleading] Come with us.",
    "You're hurt. Who are you?": "[cautious] You're hurt. Who are you?",
    "Is anyone still alive in there?": "[hopeful, tense] Is anyone still alive in there?",
    "And Sir Ivan?": "[hesitant] And Sir Ivan?",
    "Rommel, at the back gate. He said someone up here flashes a light every night.":
        "Rommel... at the back gate. He said someone up here flashes a light every night.",
    "Wait. There's someone by the gate. Sitting there.": "[whispers, alarmed] Wait. There's someone by the gate. Sitting there.",
    "That's no survivor. Look at its arm. Look at the size of that arm.":
        "[horrified] That's no survivor. Look at its arm... Look at the size of that arm!",
    "That's not him any more. The others didn't do this. It's changed into something.":
        "[grim] That's not him any more. The others didn't do this... It's changed into something.",
    "It went up right on him! Again, find another drum!": "[shouting, fired up] It went up right on him! Again! Find another drum!",
    "Behind us! They're coming up behind us!": "[yelling, panicked] Behind us! They're coming up behind us!",
    "Got it. The rear gate's key, still on the guard's ring.": "[out of breath] Got it! The rear gate's key... still on the guard's ring.",
}

# The squad's call-outs (lines.json takes), by text.
CALLOUTS = {
    "Infected, up ahead!": "[alert, sharp] Infected, up ahead!",
    "Contact! Zombie spotted!": "[shouting] Contact! Zombie spotted!",
    "Eyes up, they're coming!": "[tense] Eyes up, they're coming!",
    "There's a lot of them!": "[panicked] There's a lot of them!",
    "Here comes a whole crowd!": "[alarmed] Here comes a whole crowd!",
    "Behind you! Turn around!": "[yelling] Behind you! Turn around!",
    "Reloading!": "[shouting] Reloading!",
    "Changing mags, cover me!": "[hurried] Changing mags, cover me!",
    "I'm running low on ammo.": "[worried] I'm running low on ammo.",
    "Getting low on rounds.": "[tense] Getting low on rounds.",
    "I'm out! I'm out of ammo!": "[panicked] I'm out! I'm out of ammo!",
    "Guns over here!": "[excited] Guns over here!",
    "Got weapons here!": "Got weapons here!",
    "Ammo over here.": "Ammo over here.",
    "Found a medkit.": "[relieved] Found a medkit.",
    "Let's go, let's go!": "[urgent] Let's go, let's go!",
    "Move up, let's go!": "Move up, let's go!",
    "I need backup!": "[desperate] I need backup!",
    "Need help over here!": "[strained, shouting] Need help over here!",
    "Hey, check this out.": "[curious] Hey, check this out.",
    "On me! Follow me.": "On me! Follow me.",
    "Hold here. Watch the corners.": "[low, focused] Hold here. Watch the corners.",
    "Fall back! Fall back!": "[shouting] Fall back! Fall back!",
    "Too many, back up!": "[panicked] Too many, back up!",
    "I got you covered!": "[determined] I got you covered!",
    "Covering you!": "Covering you!",
    "I'm down! Somebody help me!": "[screaming in pain] I'm down! Somebody help me!",
    "Hang on, I got you!": "[straining] Hang on, I got you!",
    "Thanks, I owe you one.": "[relieved, breathless] Thanks, I owe you one.",
    "Got him.": "[grim] Got him.",
    "Target down.": "[calm] Target down.",
    "One less.": "[cold] One less.",
    "Clear.": "[exhales] Clear.",
    "Area's clear.": "Area's clear.",
    "I'm hit!": "[pained cry] I'm hit!",
    "Agh, it got me!": "[pained] Agh, it got me!",
    "Patching up.": "[tired] Patching up.",
    "Copy that.": "Copy that.",
    "On it.": "On it.",
    "Fire in the hole!": "[yelling] Fire in the hole!",
    "Grenade out! Fire in the hole!": "[shouting] Grenade out! Fire in the hole!",
    "Fire in the hole! Get down!": "[urgent yell] Fire in the hole! Get down!",
}


def main():
    with open(PATH, encoding='utf-8') as f:
        data = json.load(f)
    missing = []
    for ln in data['lines']:
        if ln['text'] in D:
            ln['tts'] = D[ln['text']]
        else:
            missing.append(ln['text'])
    data['callouts'] = CALLOUTS
    with open(PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    print('directed', len(data['lines']) - len(missing), 'missing', sorted(set(missing)))


if __name__ == '__main__':
    main()
