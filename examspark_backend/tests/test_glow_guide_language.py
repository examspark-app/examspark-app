from app.services.glow_guide_service import glow_guide_language_for_turn


def test_glow_guide_hindi_script_switches_to_hindi():
    assert glow_guide_language_for_turn("प्रकाश संश्लेषण क्या है?") == "HINDI"


def test_glow_guide_bengali_script_switches_to_bengali():
    assert glow_guide_language_for_turn("প্রকাশ সংশ্লেষণ কী?") == "BENGALI"


def test_glow_guide_does_dynamic_language_override_from_default():
    assert glow_guide_language_for_turn("What is photosynthesis?", "HINDI") == "ENGLISH"
