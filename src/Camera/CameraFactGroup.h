#pragma once

#include "FactGroup.h"

class QGCCameraManager;

class CameraFactGroup : public FactGroup
{
    Q_OBJECT
    Q_PROPERTY(Fact* thermalRangeMax READ thermalRangeMax CONSTANT)
    Q_PROPERTY(Fact* thermalRangeMin READ thermalRangeMin CONSTANT)

public:
    CameraFactGroup(QGCCameraManager* parent);

    Fact* thermalRangeMax() { return &_thermalRangeMaxFact; }

    Fact* thermalRangeMin() { return &_thermalRangeMinFact; }

    void setThermalRangeMax(float max) { thermalRangeMax()->setRawValue(max); }

    void setThermalRangeMin(float min) { thermalRangeMin()->setRawValue(min); }

private:
    void _initFacts();

    Fact _thermalRangeMaxFact = Fact(0, QStringLiteral("thermalRangeMax"), FactMetaData::valueTypeFloat);
    Fact _thermalRangeMinFact = Fact(0, QStringLiteral("thermalRangeMin"), FactMetaData::valueTypeFloat);
};
