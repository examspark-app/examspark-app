from app.services.glow_guide_research_service import _domains_for_query


def test_baby_research_uses_pediatric_and_safety_domains():
    domains = _domains_for_query("diaper rash ingredient safety research", "baby")

    assert "healthychildren.org" in domains
    assert "fda.gov" in domains


def test_cloth_research_uses_textile_and_care_domains():
    domains = _domains_for_query("fabric care label research", "cloth")

    assert "oeko-tex.com" in domains
    assert "ftc.gov" in domains


def test_product_research_includes_recognized_official_domain():
    domains = _domains_for_query("CeraVe cleanser ingredients", "skin")

    assert "cerave.com" in domains
    assert "cir-safety.org" in domains
