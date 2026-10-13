#include "CameraFactGroup.h"
#include "QGCCameraManager.h"

CameraFactGroup::CameraFactGroup(QGCCameraManager* parent)
    : FactGroup(1000, QStringLiteral(":/json/Vehicle/CameraFact.json"), parent)
{
    _initFacts();
}

void CameraFactGroup::_initFacts()
{
    _addFact(&_thermalRangeMaxFact);
    _addFact(&_thermalRangeMinFact);

    _thermalRangeMaxFact.setRawValue(qQNaN());
    _thermalRangeMinFact.setRawValue(qQNaN());
}
