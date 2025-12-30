import React, { useState, useMemo } from "react";
import {
  ChevronDown,
  ChevronUp,
  DollarSign,
  FileText,
  RotateCcw,
  X,
} from "lucide-react";

// ============================================================================
// DEFAULT CONFIGURATION
// All defaults are defined here for easy modification
// ============================================================================

const DEFAULT_MODELS = [
  {
    id: "gpt-4.0-azure",
    name: "GPT-4.0 - Azure OpenAI (KPMG Enterprise)",
    inputPrice: 1.966,
    outputPrice: 7.87,
    cachedPrice: 1.035,
  },
  {
    id: "gpt-4.0",
    name: "GPT-4.0",
    inputPrice: 2.5,
    outputPrice: 10.0,
    cachedPrice: 1.25,
  },
  {
    id: "gpt-4.1",
    name: "GPT-4.1",
    inputPrice: 2.0,
    outputPrice: 8.0,
    cachedPrice: 0.5,
  },
  {
    id: "gpt-5.2",
    name: "GPT-5.2",
    inputPrice: 1.75,
    outputPrice: 14.0,
    cachedPrice: 0.18,
  },
  {
    id: "grok-3",
    name: "Grok-3",
    inputPrice: 3.0,
    outputPrice: 15.0,
    cachedPrice: 0.75,
  },
  {
    id: "grok-4.1-fast",
    name: "Grok-4.1-Fast-Reasoning",
    inputPrice: 0.2,
    outputPrice: 0.5,
    cachedPrice: 0.05,
  },
  {
    id: "gemini-2.5-pro",
    name: "Gemini 2.5 Pro",
    inputPrice: 1.25,
    outputPrice: 10.0,
    cachedPrice: 0.13,
  },
  {
    id: "gemini-3-pro",
    name: "Gemini 3 Pro Preview",
    inputPrice: 2.0,
    outputPrice: 12.0,
    cachedPrice: 0.2,
  },
  {
    id: "gemini-2.5-flash",
    name: "Gemini 2.5 Flash",
    inputPrice: 0.3,
    outputPrice: 2.5,
    cachedPrice: 0.03,
  },
];

const DEFAULT_PROFILES = {
  S: {
    label: "Simple",
    pageRange: "1-5 pages",
    avgPages: 3,
    description: "IDs, proof of address, declarations, simple bank statements",
  },
  M: {
    label: "Standard",
    pageRange: "5-15 pages",
    avgPages: 10,
    description: "KYC questionnaires, simple contracts",
  },
  L: {
    label: "Large",
    pageRange: "15-50 pages",
    avgPages: 30,
    description: "Financial statements, dense contracts, internal reports",
  },
  XL: {
    label: "Very Large",
    pageRange: "50-150 pages",
    avgPages: 100,
    description: "Annual reports, regulatory docs",
  },
};

const DEFAULT_SETTINGS = {
  tokensPerPage: 700,
  extractedFields: 30,
  tokensPerField: 10,
  promptType: "standard", // 'standard' or 'custom'
  standardExtractionPromptInputTokens: 35000,
  standardExtractionPromptCachedTokens: 0,
  standardClassificationPromptInputTokens: 500,
  customExtractionPromptInputTokens: "",
  customExtractionPromptCachedTokens: "",
  customClassificationPromptInputTokens: "",
  trainedModelCostPerPage: 0.0334851,
  showTrainedModelComparison: true,
  costVariancePercentage: 20, // +/- percentage for cost range
};

// ============================================================================
// MAIN COMPONENT
// ============================================================================

export default function CostCalculator() {
  // Load saved state from localStorage or use defaults
  const loadState = (key, defaultValue) => {
    try {
      const saved = localStorage.getItem(key);
      if (!saved) return defaultValue;

      const parsed = JSON.parse(saved);

      // Special handling for settings to merge with new defaults
      if (key === "settings") {
        return { ...defaultValue, ...parsed };
      }

      return parsed;
    } catch {
      return defaultValue;
    }
  };

  // Main inputs
  const [selectedModel, setSelectedModel] = useState(() =>
    loadState("selectedModel", DEFAULT_MODELS[0].id)
  );
  const [docQuantities, setDocQuantities] = useState(() =>
    loadState("docQuantities", { S: "", M: "", L: "", XL: "" })
  );

  // Modal states
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [helpOpen, setHelpOpen] = useState(false);
  const [compareOpen, setCompareOpen] = useState(false);
  const [breakdownOpen, setBreakdownOpen] = useState(false);
  const [aiDetailsOpen, setAiDetailsOpen] = useState(false);
  const [trainedDetailsOpen, setTrainedDetailsOpen] = useState(false);

  // Collapsible sections in settings
  const [pricingOpen, setPricingOpen] = useState(false);
  const [promptConfigOpen, setPromptConfigOpen] = useState(false);
  const [profilesOpen, setProfilesOpen] = useState(false);
  const [extractionOpen, setExtractionOpen] = useState(false);
  const [trainedModelOpen, setTrainedModelOpen] = useState(false);
  const [costRangeOpen, setCostRangeOpen] = useState(false);

  // View mode state
  const [viewMode, setViewMode] = useState(() =>
    loadState("viewMode", "desktop")
  );

  // Settings state
  const [models, setModels] = useState(() =>
    loadState("models", DEFAULT_MODELS)
  );
  const [profiles, setProfiles] = useState(() =>
    loadState("profiles", DEFAULT_PROFILES)
  );
  const [settings, setSettings] = useState(() =>
    loadState("settings", DEFAULT_SETTINGS)
  );

  // Save to localStorage whenever state changes
  React.useEffect(() => {
    localStorage.setItem("selectedModel", JSON.stringify(selectedModel));
  }, [selectedModel]);

  React.useEffect(() => {
    localStorage.setItem("docQuantities", JSON.stringify(docQuantities));
  }, [docQuantities]);

  React.useEffect(() => {
    localStorage.setItem("models", JSON.stringify(models));
  }, [models]);

  React.useEffect(() => {
    localStorage.setItem("profiles", JSON.stringify(profiles));
  }, [profiles]);

  React.useEffect(() => {
    localStorage.setItem("settings", JSON.stringify(settings));
  }, [settings]);

  React.useEffect(() => {
    localStorage.setItem("viewMode", JSON.stringify(viewMode));
  }, [viewMode]);

  // Get current model pricing
  const currentModel = models.find((m) => m.id === selectedModel) || models[0];

  // ============================================================================
  // CALCULATION LOGIC
  // ============================================================================
  const costBreakdown = useMemo(() => {
    const breakdown = { S: null, M: null, L: null, XL: null };
    let totalClassificationCost = 0;
    let totalExtractionInputCost = 0;
    let totalCachedCost = 0;
    let totalOutputCost = 0;
    let totalPages = 0;

    // Determine prompt tokens based on type
    const extractionPromptInputTokens =
      settings.promptType === "standard"
        ? parseFloat(settings.standardExtractionPromptInputTokens) || 0
        : parseFloat(settings.customExtractionPromptInputTokens) || 0;

    const extractionPromptCachedTokens =
      settings.promptType === "standard"
        ? parseFloat(settings.standardExtractionPromptCachedTokens) || 0
        : parseFloat(settings.customExtractionPromptCachedTokens) || 0;

    const classificationPromptInputTokens =
      settings.promptType === "standard"
        ? parseFloat(settings.standardClassificationPromptInputTokens) || 0
        : parseFloat(settings.customClassificationPromptInputTokens) || 0;

    Object.keys(profiles).forEach((profileKey) => {
      const quantity = parseInt(docQuantities[profileKey]) || 0;
      if (quantity === 0) return;

      const profile = profiles[profileKey];

      // Calculate tokens per document
      const documentTokens = profile.avgPages * settings.tokensPerPage;

      // Classification step: classification prompt + document tokens
      const classificationInputTokensPerDoc =
        classificationPromptInputTokens + documentTokens;

      // Extraction step: extraction prompt + document tokens + cached tokens
      const extractionInputTokensPerDoc =
        extractionPromptInputTokens + documentTokens;
      const extractionCachedTokensPerDoc = extractionPromptCachedTokens;

      // Total input tokens per document (classification + extraction)
      const inputTokensPerDoc =
        classificationInputTokensPerDoc + extractionInputTokensPerDoc;
      const cachedTokensPerDoc = extractionCachedTokensPerDoc;

      // Output tokens (only for extraction, classification output is negligible)
      const outputTokensPerDoc =
        settings.extractedFields * settings.tokensPerField;

      // Calculate monthly tokens
      const monthlyClassificationInputTokens =
        classificationInputTokensPerDoc * quantity;
      const monthlyExtractionInputTokens =
        extractionInputTokensPerDoc * quantity;
      const monthlyCachedTokens = cachedTokensPerDoc * quantity;
      const monthlyOutputTokens = outputTokensPerDoc * quantity;

      // Calculate costs (price is per 1M tokens)
      const classificationCost =
        (monthlyClassificationInputTokens / 1_000_000) *
        currentModel.inputPrice;
      const extractionInputCost =
        (monthlyExtractionInputTokens / 1_000_000) * currentModel.inputPrice;
      const cachedCost =
        (monthlyCachedTokens / 1_000_000) * currentModel.cachedPrice;
      const outputCost =
        (monthlyOutputTokens / 1_000_000) * currentModel.outputPrice;

      // Add to total pages
      totalPages += profile.avgPages * quantity;

      breakdown[profileKey] = {
        quantity,
        inputTokensPerDoc,
        cachedTokensPerDoc,
        outputTokensPerDoc,
        monthlyClassificationInputTokens,
        monthlyExtractionInputTokens,
        monthlyCachedTokens,
        monthlyOutputTokens,
        classificationCost,
        extractionInputCost,
        cachedCost,
        outputCost,
        totalCost:
          classificationCost + extractionInputCost + cachedCost + outputCost,
      };

      totalClassificationCost += classificationCost;
      totalExtractionInputCost += extractionInputCost;
      totalCachedCost += cachedCost;
      totalOutputCost += outputCost;
    });

    // Calculate trained model cost
    const trainedModelCost =
      totalPages * (parseFloat(settings.trainedModelCostPerPage) || 0);

    return {
      profiles: breakdown,
      totalClassificationCost,
      totalExtractionInputCost,
      totalInputCost: totalClassificationCost + totalExtractionInputCost,
      totalCachedCost,
      totalOutputCost,
      totalCost:
        totalClassificationCost +
        totalExtractionInputCost +
        totalCachedCost +
        totalOutputCost,
      totalPages,
      trainedModelCost,
    };
  }, [docQuantities, profiles, settings, currentModel]);

  // Calculate costs for all models (for comparison)
  const allModelsCosts = useMemo(() => {
    return models.map((model) => {
      let totalInputCost = 0;
      let totalCachedCost = 0;
      let totalOutputCost = 0;

      // Determine prompt tokens based on type
      const extractionPromptInputTokens =
        settings.promptType === "standard"
          ? parseFloat(settings.standardExtractionPromptInputTokens) || 0
          : parseFloat(settings.customExtractionPromptInputTokens) || 0;

      const extractionPromptCachedTokens =
        settings.promptType === "standard"
          ? parseFloat(settings.standardExtractionPromptCachedTokens) || 0
          : parseFloat(settings.customExtractionPromptCachedTokens) || 0;

      const classificationPromptInputTokens =
        settings.promptType === "standard"
          ? parseFloat(settings.standardClassificationPromptInputTokens) || 0
          : parseFloat(settings.customClassificationPromptInputTokens) || 0;

      Object.keys(profiles).forEach((profileKey) => {
        const quantity = parseInt(docQuantities[profileKey]) || 0;
        if (quantity === 0) return;

        const profile = profiles[profileKey];
        const documentTokens = profile.avgPages * settings.tokensPerPage;

        // Classification step
        const classificationInputTokensPerDoc =
          classificationPromptInputTokens + documentTokens;

        // Extraction step
        const extractionInputTokensPerDoc =
          extractionPromptInputTokens + documentTokens;
        const extractionCachedTokensPerDoc = extractionPromptCachedTokens;

        // Total
        const inputTokensPerDoc =
          classificationInputTokensPerDoc + extractionInputTokensPerDoc;
        const cachedTokensPerDoc = extractionCachedTokensPerDoc;
        const outputTokensPerDoc =
          settings.extractedFields * settings.tokensPerField;

        const monthlyInputTokens = inputTokensPerDoc * quantity;
        const monthlyCachedTokens = cachedTokensPerDoc * quantity;
        const monthlyOutputTokens = outputTokensPerDoc * quantity;

        const inputCost = (monthlyInputTokens / 1_000_000) * model.inputPrice;
        const cachedCost =
          (monthlyCachedTokens / 1_000_000) * model.cachedPrice;
        const outputCost =
          (monthlyOutputTokens / 1_000_000) * model.outputPrice;

        totalInputCost += inputCost;
        totalCachedCost += cachedCost;
        totalOutputCost += outputCost;
      });

      return {
        model: model.name,
        modelId: model.id,
        totalInputCost,
        totalCachedCost,
        totalOutputCost,
        totalCost: totalInputCost + totalCachedCost + totalOutputCost,
      };
    });
  }, [models, docQuantities, profiles, settings]);

  // Reset to defaults
  const resetSettings = () => {
    setModels(DEFAULT_MODELS);
    setProfiles(DEFAULT_PROFILES);
    setSettings(DEFAULT_SETTINGS);
  };

  // Update model pricing
  const updateModelPrice = (modelId, field, value) => {
    setModels(
      models.map((m) =>
        m.id === modelId ? { ...m, [field]: parseFloat(value) || 0 } : m
      )
    );
  };

  // Update profile settings
  const updateProfile = (profileKey, field, value) => {
    setProfiles({
      ...profiles,
      [profileKey]: {
        ...profiles[profileKey],
        [field]: parseFloat(value) || 0,
      },
    });
  };

  // Update general settings
  const updateSetting = (field, value) => {
    setSettings({ ...settings, [field]: value });
  };

  // Add new model
  const addNewModel = () => {
    const newId = `custom-model-${Date.now()}`;
    setModels([
      ...models,
      {
        id: newId,
        name: "New Custom Model",
        inputPrice: 0,
        outputPrice: 0,
        cachedPrice: 0,
      },
    ]);
  };

  // Update model name
  const updateModelName = (modelId, newName) => {
    setModels(
      models.map((m) => (m.id === modelId ? { ...m, name: newName } : m))
    );
  };

  // Delete model
  const deleteModel = (modelId) => {
    if (models.length <= 1) {
      alert("You must have at least one model");
      return;
    }
    setModels(models.filter((m) => m.id !== modelId));
    // If deleted model was selected, select first remaining model
    if (selectedModel === modelId) {
      setSelectedModel(models.filter((m) => m.id !== modelId)[0].id);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100 p-4 md:p-8">
      <div
        className={`mx-auto transition-all duration-300 ${
          viewMode === "mobile" ? "max-w-md" : "max-w-7xl"
        }`}
      >
        {/* Header */}
        <div className="mb-8 flex items-start justify-between">
          <div>
            <h1 className="text-3xl font-bold text-slate-900 mb-2 flex items-center gap-3">
              <FileText className="text-blue-600" size={32} />
              AI Document Extraction Cost Calculator
            </h1>
            <p className="text-slate-600">Estimate monthly costs</p>
          </div>

          {/* Top right icons */}
          <div className="flex gap-2">
            <button
              onClick={() =>
                setViewMode(viewMode === "desktop" ? "mobile" : "desktop")
              }
              className="p-3 bg-white rounded-lg shadow-sm border border-slate-200 hover:bg-slate-50 transition-colors"
              title={
                viewMode === "desktop"
                  ? "Switch to mobile view"
                  : "Switch to desktop view"
              }
            >
              {viewMode === "desktop" ? (
                <svg
                  className="text-slate-600"
                  width="20"
                  height="20"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <rect x="5" y="2" width="14" height="20" rx="2" ry="2" />
                  <line x1="12" y1="18" x2="12.01" y2="18" />
                </svg>
              ) : (
                <svg
                  className="text-slate-600"
                  width="20"
                  height="20"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
                  <line x1="8" y1="21" x2="16" y2="21" />
                  <line x1="12" y1="17" x2="12" y2="21" />
                </svg>
              )}
            </button>
            <button
              onClick={() => setHelpOpen(true)}
              className="p-3 bg-white rounded-lg shadow-sm border border-slate-200 hover:bg-slate-50 transition-colors"
              title="Help & Guide"
            >
              <svg
                className="text-slate-600"
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <circle cx="12" cy="12" r="10" />
                <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3" />
                <line x1="12" y1="17" x2="12.01" y2="17" />
              </svg>
            </button>
            <button
              onClick={() => setSettingsOpen(true)}
              className="p-3 bg-white rounded-lg shadow-sm border border-slate-200 hover:bg-slate-50 transition-colors"
              title="Advanced settings"
            >
              <svg
                className="text-slate-600"
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z" />
                <circle cx="12" cy="12" r="3" />
              </svg>
            </button>
          </div>
        </div>

        {/* Main Content */}
        <div className="space-y-6">
          {/* Model Selection - Full Width */}
          <div className="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
            <label className="block text-sm font-semibold text-slate-700 mb-3">
              AI Model
            </label>
            <select
              value={selectedModel}
              onChange={(e) => setSelectedModel(e.target.value)}
              className="w-full px-4 py-3 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-slate-900 bg-white"
            >
              {models.map((model) => (
                <option key={model.id} value={model.id}>
                  {model.name}
                </option>
              ))}
            </select>
            <div className="mt-3 text-sm text-slate-600">
              <div className="flex justify-between">
                <span>Input: ${currentModel.inputPrice}/1M</span>
                <span>Cached: ${currentModel.cachedPrice}/1M</span>
                <span>Output: ${currentModel.outputPrice}/1M</span>
              </div>
            </div>
          </div>

          {/* Two Column Layout - Document Quantities and Cost Summary */}
          <div
            className={`grid gap-6 ${
              viewMode === "mobile" ? "grid-cols-1" : "grid-cols-2"
            }`}
          >
            {/* LEFT - Document Quantities */}
            <div className="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
              <h3 className="text-sm font-semibold text-slate-700 mb-4">
                Monthly Document Quantities
              </h3>
              <div className="space-y-4">
                {Object.entries(profiles).map(([key, profile]) => (
                  <div key={key} className="space-y-2">
                    <div className="flex items-center justify-between">
                      <div>
                        <span className="font-semibold text-slate-900">
                          {key} — {profile.label}
                        </span>
                        <span className="text-sm text-slate-500 ml-2">
                          ({profile.pageRange})
                        </span>
                      </div>
                      <input
                        type="number"
                        min="0"
                        value={docQuantities[key]}
                        onChange={(e) =>
                          setDocQuantities({
                            ...docQuantities,
                            [key]: e.target.value,
                          })
                        }
                        className="w-28 px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-right"
                        placeholder="0"
                      />
                    </div>
                    <p className="text-xs text-slate-500 italic">
                      {profile.description}
                    </p>
                  </div>
                ))}
              </div>
            </div>

            {/* RIGHT - Cost Summary */}
            <div className="bg-gradient-to-br from-blue-50 to-blue-100 rounded-lg shadow-md border border-blue-200 p-6">
              <div className="flex items-center gap-2 mb-4">
                <DollarSign className="text-blue-600" size={24} />
                <h3 className="text-lg font-bold text-slate-900">
                  Monthly Cost Comparison
                </h3>
              </div>

              {/* AI Extraction Model Cost */}
              <div className="bg-white rounded-lg p-4 mb-3 border-2 border-blue-300">
                <div className="flex items-center justify-between mb-1">
                  <div className="text-xs text-blue-600 font-semibold">
                    AI EXTRACTION MODEL
                  </div>
                  <button
                    onClick={() => setBreakdownOpen(!breakdownOpen)}
                    className="text-blue-600 hover:text-blue-700 text-xs underline"
                  >
                    {breakdownOpen ? "Hide" : "Show"} calculation
                  </button>
                </div>
                <div className="mb-2">
                  <div className="text-3xl font-bold text-blue-600">
                    $
                    {Math.round(
                      costBreakdown.totalCost *
                        (1 - settings.costVariancePercentage / 100)
                    )}{" "}
                    – $
                    {Math.round(
                      costBreakdown.totalCost *
                        (1 + settings.costVariancePercentage / 100)
                    )}
                  </div>
                  <div className="text-xs text-slate-500 mt-1">
                    Estimated range (±{settings.costVariancePercentage}%)
                  </div>
                </div>

                {/* Collapsible details */}
                <div className="border-t border-blue-200 pt-2">
                  <button
                    onClick={() => setAiDetailsOpen(!aiDetailsOpen)}
                    className="flex items-center gap-1 text-xs text-blue-600 hover:text-blue-700"
                  >
                    {aiDetailsOpen ? (
                      <ChevronUp size={14} />
                    ) : (
                      <ChevronDown size={14} />
                    )}
                    {aiDetailsOpen ? "Hide" : "Show"} details
                  </button>

                  {aiDetailsOpen && (
                    <div className="text-xs text-slate-500 space-y-0.5 mt-2">
                      <div>
                        Classification: $
                        {costBreakdown.totalClassificationCost.toFixed(2)}
                      </div>
                      <div>
                        Extraction Input: $
                        {costBreakdown.totalExtractionInputCost.toFixed(2)}
                      </div>
                      <div>
                        Cached: ${costBreakdown.totalCachedCost.toFixed(2)}
                      </div>
                      <div>
                        Output: ${costBreakdown.totalOutputCost.toFixed(2)}
                      </div>
                    </div>
                  )}
                </div>

                {/* Detailed Breakdown */}
                {breakdownOpen &&
                  Object.entries(costBreakdown.profiles).some(
                    ([_, v]) => v !== null
                  ) && (
                    <div className="mt-4 pt-4 border-t border-blue-200 space-y-3">
                      <div className="text-xs font-semibold text-slate-700">
                        Detailed Calculation:
                      </div>

                      {/* Model Info */}
                      <div className="bg-slate-50 rounded p-2 text-xs space-y-1">
                        <div className="font-semibold text-slate-700">
                          Model: {currentModel.name}
                        </div>
                        <div className="text-slate-600">
                          Input: ${currentModel.inputPrice}/1M tokens
                        </div>
                        <div className="text-slate-600">
                          Cached: ${currentModel.cachedPrice}/1M tokens
                        </div>
                        <div className="text-slate-600">
                          Output: ${currentModel.outputPrice}/1M tokens
                        </div>
                      </div>

                      {/* Per-profile breakdown */}
                      {Object.entries(costBreakdown.profiles).map(
                        ([key, data]) =>
                          data && (
                            <div
                              key={key}
                              className="bg-blue-50 rounded p-3 text-xs space-y-2"
                            >
                              <div className="font-semibold text-blue-900">
                                Profile {key} ({profiles[key].label}) -{" "}
                                {data.quantity} documents
                              </div>

                              <div className="space-y-1 text-slate-700">
                                <div className="font-medium text-slate-800">
                                  Per Document:
                                </div>
                                <div className="ml-2">
                                  • Pages: {profiles[key].avgPages}
                                </div>
                                <div className="ml-2">
                                  • Document tokens: {profiles[key].avgPages} ×{" "}
                                  {settings.tokensPerPage} ={" "}
                                  {(
                                    profiles[key].avgPages *
                                    settings.tokensPerPage
                                  ).toLocaleString()}
                                </div>
                              </div>

                              <div className="space-y-1 text-slate-700">
                                <div className="font-medium text-slate-800">
                                  Classification Step:
                                </div>
                                <div className="ml-2">
                                  • Tokens:{" "}
                                  {(settings.promptType === "standard"
                                    ? settings.standardClassificationPromptInputTokens
                                    : settings.customClassificationPromptInputTokens
                                  ).toLocaleString()}{" "}
                                  (prompt) +{" "}
                                  {(
                                    profiles[key].avgPages *
                                    settings.tokensPerPage
                                  ).toLocaleString()}{" "}
                                  (doc) ={" "}
                                  {(
                                    data.monthlyClassificationInputTokens /
                                    data.quantity
                                  ).toLocaleString()}
                                </div>
                                <div className="ml-2">
                                  • Monthly:{" "}
                                  {data.monthlyClassificationInputTokens.toLocaleString()}{" "}
                                  tokens × {data.quantity} docs
                                </div>
                                <div className="ml-2 font-semibold text-blue-700">
                                  • Cost:{" "}
                                  {data.monthlyClassificationInputTokens.toLocaleString()}{" "}
                                  ÷ 1M × ${currentModel.inputPrice} = $
                                  {data.classificationCost.toFixed(2)}
                                </div>
                              </div>

                              <div className="space-y-1 text-slate-700">
                                <div className="font-medium text-slate-800">
                                  Extraction Step:
                                </div>
                                <div className="ml-2">
                                  • Input tokens:{" "}
                                  {(settings.promptType === "standard"
                                    ? settings.standardExtractionPromptInputTokens
                                    : settings.customExtractionPromptInputTokens
                                  ).toLocaleString()}{" "}
                                  (prompt) +{" "}
                                  {(
                                    profiles[key].avgPages *
                                    settings.tokensPerPage
                                  ).toLocaleString()}{" "}
                                  (doc) ={" "}
                                  {(
                                    data.monthlyExtractionInputTokens /
                                    data.quantity
                                  ).toLocaleString()}
                                </div>
                                <div className="ml-2">
                                  • Monthly input:{" "}
                                  {data.monthlyExtractionInputTokens.toLocaleString()}{" "}
                                  tokens
                                </div>
                                <div className="ml-2 font-semibold text-blue-700">
                                  • Input cost:{" "}
                                  {data.monthlyExtractionInputTokens.toLocaleString()}{" "}
                                  ÷ 1M × ${currentModel.inputPrice} = $
                                  {data.extractionInputCost.toFixed(2)}
                                </div>

                                {data.monthlyCachedTokens > 0 && (
                                  <>
                                    <div className="ml-2">
                                      • Cached tokens:{" "}
                                      {(
                                        data.monthlyCachedTokens / data.quantity
                                      ).toLocaleString()}{" "}
                                      per doc
                                    </div>
                                    <div className="ml-2">
                                      • Monthly cached:{" "}
                                      {data.monthlyCachedTokens.toLocaleString()}{" "}
                                      tokens
                                    </div>
                                    <div className="ml-2 font-semibold text-blue-700">
                                      • Cached cost:{" "}
                                      {data.monthlyCachedTokens.toLocaleString()}{" "}
                                      ÷ 1M × ${currentModel.cachedPrice} = $
                                      {data.cachedCost.toFixed(2)}
                                    </div>
                                  </>
                                )}

                                <div className="ml-2">
                                  • Output tokens: {settings.extractedFields}{" "}
                                  fields × {settings.tokensPerField} ={" "}
                                  {data.outputTokensPerDoc}
                                </div>
                                <div className="ml-2">
                                  • Monthly output:{" "}
                                  {data.monthlyOutputTokens.toLocaleString()}{" "}
                                  tokens
                                </div>
                                <div className="ml-2 font-semibold text-blue-700">
                                  • Output cost:{" "}
                                  {data.monthlyOutputTokens.toLocaleString()} ÷
                                  1M × ${currentModel.outputPrice} = $
                                  {data.outputCost.toFixed(2)}
                                </div>
                              </div>

                              <div className="pt-2 border-t border-blue-200 font-bold text-blue-900">
                                Profile {key} Total: $
                                {data.totalCost.toFixed(2)}
                              </div>
                            </div>
                          )
                      )}

                      {/* Grand Total */}
                      <div className="bg-blue-100 rounded p-3 space-y-1 text-xs font-semibold">
                        <div className="text-blue-900">
                          Monthly Total Breakdown:
                        </div>
                        <div className="text-blue-800">
                          Classification: $
                          {costBreakdown.totalClassificationCost.toFixed(2)}
                        </div>
                        <div className="text-blue-800">
                          Extraction Input: $
                          {costBreakdown.totalExtractionInputCost.toFixed(2)}
                        </div>
                        <div className="text-blue-800">
                          Cached: ${costBreakdown.totalCachedCost.toFixed(2)}
                        </div>
                        <div className="text-blue-800">
                          Output: ${costBreakdown.totalOutputCost.toFixed(2)}
                        </div>
                        <div className="text-blue-900 text-base pt-2 border-t border-blue-300">
                          Grand Total: ${costBreakdown.totalCost.toFixed(2)}
                        </div>
                      </div>
                    </div>
                  )}
              </div>

              {/* Trained Documents Model Cost */}
              {settings.showTrainedModelComparison &&
                costBreakdown.totalPages > 0 && (
                  <>
                    <div className="bg-white rounded-lg p-4 mb-3 border-2 border-slate-300">
                      <div className="text-xs text-slate-600 font-semibold mb-1">
                        TRAINED DOCUMENTS MODEL
                      </div>
                      <div className="mb-2">
                        <div className="text-3xl font-bold text-slate-700">
                          $
                          {Math.round(
                            costBreakdown.trainedModelCost *
                              (1 - settings.costVariancePercentage / 100)
                          )}{" "}
                          – $
                          {Math.round(
                            costBreakdown.trainedModelCost *
                              (1 + settings.costVariancePercentage / 100)
                          )}
                        </div>
                        <div className="text-xs text-slate-500 mt-1">
                          Estimated range (±{settings.costVariancePercentage}%)
                        </div>
                      </div>

                      {/* Collapsible details */}
                      <div className="border-t border-slate-300 pt-2">
                        <button
                          onClick={() =>
                            setTrainedDetailsOpen(!trainedDetailsOpen)
                          }
                          className="flex items-center gap-1 text-xs text-slate-600 hover:text-slate-700"
                        >
                          {trainedDetailsOpen ? (
                            <ChevronUp size={14} />
                          ) : (
                            <ChevronDown size={14} />
                          )}
                          {trainedDetailsOpen ? "Hide" : "Show"} details
                        </button>

                        {trainedDetailsOpen && (
                          <div className="text-xs text-slate-500 space-y-0.5 mt-2">
                            <div>
                              {costBreakdown.totalPages.toLocaleString()} pages
                              × ${settings.trainedModelCostPerPage}/page
                            </div>
                            <div>
                              Classification (10%): $
                              {(costBreakdown.trainedModelCost * 0.1).toFixed(
                                2
                              )}
                            </div>
                            <div>
                              Extraction (90%): $
                              {(costBreakdown.trainedModelCost * 0.9).toFixed(
                                2
                              )}
                            </div>
                          </div>
                        )}
                      </div>
                    </div>

                    {/* Cost Difference */}
                    <div
                      className={`rounded-lg p-4 mb-4 border-2 ${
                        costBreakdown.totalCost < costBreakdown.trainedModelCost
                          ? "bg-green-50 border-green-300"
                          : costBreakdown.totalCost >
                            costBreakdown.trainedModelCost
                          ? "bg-red-50 border-red-300"
                          : "bg-slate-50 border-slate-300"
                      }`}
                    >
                      <div className="text-xs font-semibold mb-1 text-slate-700">
                        DIFFERENCE
                      </div>
                      <div className="mb-2">
                        <div
                          className={`text-3xl font-bold ${
                            costBreakdown.totalCost <
                            costBreakdown.trainedModelCost
                              ? "text-green-600"
                              : costBreakdown.totalCost >
                                costBreakdown.trainedModelCost
                              ? "text-red-600"
                              : "text-slate-600"
                          }`}
                        >
                          <span className="text-2xl">
                            {costBreakdown.totalCost <
                            costBreakdown.trainedModelCost
                              ? "-"
                              : "+"}
                          </span>
                          {Math.abs(
                            ((costBreakdown.totalCost -
                              costBreakdown.trainedModelCost) /
                              costBreakdown.trainedModelCost) *
                              100
                          ).toFixed(0)}
                          %<span className="mx-2">•</span>
                          <span className="text-2xl">
                            {costBreakdown.totalCost <
                            costBreakdown.trainedModelCost
                              ? "-"
                              : "+"}
                          </span>
                          $
                          {Math.round(
                            Math.abs(
                              costBreakdown.totalCost -
                                costBreakdown.trainedModelCost
                            )
                          )}
                        </div>
                        <div className="text-xs text-slate-500 mt-1">
                          {costBreakdown.totalCost <
                          costBreakdown.trainedModelCost
                            ? "✓ AI Extraction saves money"
                            : costBreakdown.totalCost >
                              costBreakdown.trainedModelCost
                            ? "⚠ AI Extraction costs more"
                            : "= Same cost"}
                        </div>
                      </div>
                    </div>
                  </>
                )}

              {/* Per-profile breakdown */}
              {Object.entries(costBreakdown.profiles).some(
                ([_, v]) => v !== null
              ) && (
                <div className="border-t border-blue-200 pt-4 mb-4">
                  <h4 className="text-sm font-semibold text-slate-700 mb-3">
                    AI Extraction by Profile
                  </h4>
                  <div className="space-y-2">
                    {Object.entries(costBreakdown.profiles).map(
                      ([key, data]) =>
                        data && (
                          <div
                            key={key}
                            className="flex justify-between text-sm"
                          >
                            <span className="text-slate-600">
                              {key} ({data.quantity} docs)
                            </span>
                            <span className="font-medium text-slate-900">
                              ${data.totalCost.toFixed(2)}
                            </span>
                          </div>
                        )
                    )}
                  </div>
                </div>
              )}

              {/* Compare Models Button */}
              <div className="border-t border-blue-200 pt-4">
                <button
                  onClick={() => setCompareOpen(true)}
                  className="w-full px-4 py-3 bg-white hover:bg-blue-50 text-blue-600 font-semibold rounded-lg transition-colors border-2 border-blue-200 hover:border-blue-300 flex items-center justify-center gap-2"
                >
                  <svg
                    width="20"
                    height="20"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  >
                    <line x1="18" y1="20" x2="18" y2="10" />
                    <line x1="12" y1="20" x2="12" y2="4" />
                    <line x1="6" y1="20" x2="6" y2="14" />
                  </svg>
                  Compare All AI Models
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* Compare Models Modal */}
        {compareOpen && (
          <div
            className="fixed inset-0 bg-black bg-opacity-50 flex items-start justify-center p-4 z-50 overflow-y-auto"
            onClick={() => setCompareOpen(false)}
          >
            <div
              className="bg-white rounded-lg shadow-xl max-w-6xl w-full my-8"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="bg-gradient-to-r from-blue-600 to-indigo-600 text-white px-6 py-4 flex items-center justify-between rounded-t-lg sticky top-0 z-10">
                <h3 className="text-lg font-bold flex items-center gap-2">
                  <svg
                    width="24"
                    height="24"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  >
                    <line x1="18" y1="20" x2="18" y2="10" />
                    <line x1="12" y1="20" x2="12" y2="4" />
                    <line x1="6" y1="20" x2="6" y2="14" />
                  </svg>
                  Model Cost Comparison
                </h3>
                <button
                  onClick={() => setCompareOpen(false)}
                  className="p-2 hover:bg-white hover:bg-opacity-20 rounded transition-colors flex-shrink-0"
                  title="Close"
                >
                  <X size={20} />
                </button>
              </div>

              <div
                className="p-6 overflow-y-auto"
                style={{ maxHeight: "calc(90vh - 80px)" }}
              >
                {allModelsCosts.length === 0 ||
                allModelsCosts.every((m) => m.totalCost === 0) ? (
                  <div className="text-center py-12">
                    <div className="text-slate-400 mb-4">
                      <svg
                        className="mx-auto"
                        width="64"
                        height="64"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      >
                        <line x1="18" y1="20" x2="18" y2="10" />
                        <line x1="12" y1="20" x2="12" y2="4" />
                        <line x1="6" y1="20" x2="6" y2="14" />
                      </svg>
                    </div>
                    <p className="text-slate-600 text-lg">
                      Enter document quantities to see cost comparisons
                    </p>
                  </div>
                ) : (
                  <div className="space-y-6">
                    {/* Summary Cards */}
                    <div className="grid md:grid-cols-3 gap-4">
                      <div className="bg-green-50 border border-green-200 rounded-lg p-4">
                        <div className="text-sm text-green-600 mb-1">
                          Most Economical AI Model
                        </div>
                        <div className="font-bold text-lg text-green-900">
                          {
                            allModelsCosts.reduce((min, m) =>
                              m.totalCost < min.totalCost ? m : min
                            ).model
                          }
                        </div>
                        <div className="text-2xl font-bold text-green-600 mt-2">
                          $
                          {allModelsCosts
                            .reduce((min, m) =>
                              m.totalCost < min.totalCost ? m : min
                            )
                            .totalCost.toFixed(2)}
                        </div>
                      </div>

                      <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                        <div className="text-sm text-blue-600 mb-1">
                          Currently Selected
                        </div>
                        <div className="font-bold text-lg text-blue-900">
                          {currentModel.name}
                        </div>
                        <div className="text-2xl font-bold text-blue-600 mt-2">
                          ${costBreakdown.totalCost.toFixed(2)}
                        </div>
                      </div>

                      {settings.showTrainedModelComparison && (
                        <div className="bg-purple-50 border border-purple-200 rounded-lg p-4">
                          <div className="text-sm text-purple-600 mb-1">
                            Trained Documents Model
                          </div>
                          <div className="font-bold text-lg text-purple-900">
                            ${settings.trainedModelCostPerPage}/page
                          </div>
                          <div className="text-2xl font-bold text-purple-600 mt-2">
                            ${costBreakdown.trainedModelCost.toFixed(2)}
                          </div>
                        </div>
                      )}
                    </div>

                    {/* Comparison with Trained Model */}
                    {settings.showTrainedModelComparison &&
                      costBreakdown.totalPages > 0 && (
                        <div
                          className={`rounded-lg p-6 border-2 ${
                            allModelsCosts.reduce((min, m) =>
                              m.totalCost < min.totalCost ? m : min
                            ).totalCost < costBreakdown.trainedModelCost
                              ? "bg-green-50 border-green-300"
                              : "bg-amber-50 border-amber-300"
                          }`}
                        >
                          <h4 className="font-semibold text-slate-900 mb-3 flex items-center gap-2">
                            <svg
                              width="20"
                              height="20"
                              viewBox="0 0 24 24"
                              fill="none"
                              stroke="currentColor"
                              strokeWidth="2"
                              strokeLinecap="round"
                              strokeLinejoin="round"
                            >
                              <polyline points="22 12 18 12 15 21 9 3 6 12 2 12" />
                            </svg>
                            AI vs. Trained Documents Model
                          </h4>
                          <div className="grid md:grid-cols-2 gap-4">
                            <div>
                              <div className="text-sm text-slate-600 mb-1">
                                Best AI Model vs. Trained
                              </div>
                              <div
                                className={`text-3xl font-bold ${
                                  allModelsCosts.reduce((min, m) =>
                                    m.totalCost < min.totalCost ? m : min
                                  ).totalCost < costBreakdown.trainedModelCost
                                    ? "text-green-600"
                                    : "text-amber-600"
                                }`}
                              >
                                {allModelsCosts.reduce((min, m) =>
                                  m.totalCost < min.totalCost ? m : min
                                ).totalCost < costBreakdown.trainedModelCost
                                  ? "-"
                                  : "+"}
                                $
                                {Math.abs(
                                  allModelsCosts.reduce((min, m) =>
                                    m.totalCost < min.totalCost ? m : min
                                  ).totalCost - costBreakdown.trainedModelCost
                                ).toFixed(2)}
                              </div>
                              <div className="text-sm text-slate-600 mt-1">
                                {allModelsCosts.reduce((min, m) =>
                                  m.totalCost < min.totalCost ? m : min
                                ).totalCost < costBreakdown.trainedModelCost
                                  ? `${Math.abs(
                                      ((allModelsCosts.reduce((min, m) =>
                                        m.totalCost < min.totalCost ? m : min
                                      ).totalCost -
                                        costBreakdown.trainedModelCost) /
                                        costBreakdown.trainedModelCost) *
                                        100
                                    ).toFixed(1)}% savings with ${
                                      allModelsCosts.reduce((min, m) =>
                                        m.totalCost < min.totalCost ? m : min
                                      ).model
                                    }`
                                  : `${Math.abs(
                                      ((allModelsCosts.reduce((min, m) =>
                                        m.totalCost < min.totalCost ? m : min
                                      ).totalCost -
                                        costBreakdown.trainedModelCost) /
                                        costBreakdown.trainedModelCost) *
                                        100
                                    ).toFixed(
                                      1
                                    )}% more expensive than Trained Model`}
                              </div>
                            </div>
                            <div>
                              <div className="text-sm text-slate-600 mb-1">
                                Your Selection vs. Trained
                              </div>
                              <div
                                className={`text-3xl font-bold ${
                                  costBreakdown.totalCost <
                                  costBreakdown.trainedModelCost
                                    ? "text-green-600"
                                    : "text-amber-600"
                                }`}
                              >
                                {costBreakdown.totalCost <
                                costBreakdown.trainedModelCost
                                  ? "-"
                                  : "+"}
                                $
                                {Math.abs(
                                  costBreakdown.totalCost -
                                    costBreakdown.trainedModelCost
                                ).toFixed(2)}
                              </div>
                              <div className="text-sm text-slate-600 mt-1">
                                {costBreakdown.totalCost <
                                costBreakdown.trainedModelCost
                                  ? `${Math.abs(
                                      ((costBreakdown.totalCost -
                                        costBreakdown.trainedModelCost) /
                                        costBreakdown.trainedModelCost) *
                                        100
                                    ).toFixed(1)}% savings with ${
                                      currentModel.name
                                    }`
                                  : `${Math.abs(
                                      ((costBreakdown.totalCost -
                                        costBreakdown.trainedModelCost) /
                                        costBreakdown.trainedModelCost) *
                                        100
                                    ).toFixed(
                                      1
                                    )}% more expensive than Trained Model`}
                              </div>
                            </div>
                          </div>
                        </div>
                      )}

                    {/* Visual Bar Chart */}
                    <div className="bg-slate-50 rounded-lg p-6 border border-slate-200">
                      <h4 className="font-semibold text-slate-900 mb-4">
                        Total Monthly Cost Comparison
                      </h4>
                      <div className="space-y-3">
                        {/* Add Trained Documents Model as first bar - only if enabled */}
                        {settings.showTrainedModelComparison &&
                          costBreakdown.totalPages > 0 &&
                          (() => {
                            const allCosts = [
                              ...allModelsCosts.map((m) => m.totalCost),
                              costBreakdown.trainedModelCost,
                            ];
                            const maxCost = Math.max(...allCosts);
                            const trainedPercentage =
                              maxCost > 0
                                ? (costBreakdown.trainedModelCost / maxCost) *
                                  100
                                : 0;

                            return (
                              <div className="space-y-1">
                                <div className="flex items-center justify-between text-sm">
                                  <span className="font-medium text-purple-700">
                                    Trained Documents Model
                                    <span className="ml-2 text-xs bg-purple-100 text-purple-700 px-2 py-0.5 rounded">
                                      Baseline
                                    </span>
                                  </span>
                                  <span className="font-bold text-slate-900">
                                    ${costBreakdown.trainedModelCost.toFixed(2)}
                                  </span>
                                </div>
                                <div className="h-8 bg-slate-200 rounded-full overflow-hidden">
                                  <div
                                    className="h-full flex items-center justify-end px-3 text-white text-sm font-semibold transition-all duration-500 bg-gradient-to-r from-purple-500 to-purple-600"
                                    style={{ width: `${trainedPercentage}%` }}
                                  >
                                    {trainedPercentage > 15 &&
                                      `${trainedPercentage.toFixed(0)}%`}
                                  </div>
                                </div>
                              </div>
                            );
                          })()}

                        {allModelsCosts
                          .sort((a, b) => a.totalCost - b.totalCost)
                          .map((modelCost, index) => {
                            const allCosts = settings.showTrainedModelComparison
                              ? [
                                  ...allModelsCosts.map((m) => m.totalCost),
                                  costBreakdown.trainedModelCost,
                                ]
                              : allModelsCosts.map((m) => m.totalCost);
                            const maxCost = Math.max(...allCosts);
                            const percentage =
                              maxCost > 0
                                ? (modelCost.totalCost / maxCost) * 100
                                : 0;
                            const isSelected =
                              modelCost.modelId === selectedModel;
                            const isCheapest =
                              modelCost.totalCost ===
                              Math.min(
                                ...allModelsCosts.map((m) => m.totalCost)
                              );

                            return (
                              <div
                                key={modelCost.modelId}
                                className="space-y-1"
                              >
                                <div className="flex items-center justify-between text-sm">
                                  <span
                                    className={`font-medium ${
                                      isSelected
                                        ? "text-blue-600"
                                        : "text-slate-700"
                                    }`}
                                  >
                                    {modelCost.model}
                                    {isSelected && (
                                      <span className="ml-2 text-xs bg-blue-100 text-blue-700 px-2 py-0.5 rounded">
                                        Selected
                                      </span>
                                    )}
                                    {isCheapest && (
                                      <span className="ml-2 text-xs bg-green-100 text-green-700 px-2 py-0.5 rounded">
                                        Best AI
                                      </span>
                                    )}
                                  </span>
                                  <span className="font-bold text-slate-900">
                                    ${modelCost.totalCost.toFixed(2)}
                                  </span>
                                </div>
                                <div className="h-8 bg-slate-200 rounded-full overflow-hidden">
                                  <div
                                    className={`h-full flex items-center justify-end px-3 text-white text-sm font-semibold transition-all duration-500 ${
                                      isSelected
                                        ? "bg-gradient-to-r from-blue-500 to-blue-600"
                                        : isCheapest
                                        ? "bg-gradient-to-r from-green-500 to-green-600"
                                        : "bg-gradient-to-r from-slate-400 to-slate-500"
                                    }`}
                                    style={{ width: `${percentage}%` }}
                                  >
                                    {percentage > 15 &&
                                      `${percentage.toFixed(0)}%`}
                                  </div>
                                </div>
                              </div>
                            );
                          })}
                      </div>
                    </div>

                    {/* Cost Breakdown Table */}
                    <div className="bg-white rounded-lg border border-slate-200 overflow-hidden">
                      <h4 className="font-semibold text-slate-900 px-6 py-4 bg-slate-50 border-b border-slate-200">
                        Detailed Cost Breakdown
                      </h4>
                      <div className="overflow-x-auto">
                        <table className="w-full text-sm">
                          <thead className="bg-slate-100">
                            <tr>
                              <th className="px-6 py-3 text-left font-semibold text-slate-700">
                                Model
                              </th>
                              <th className="px-6 py-3 text-right font-semibold text-slate-700">
                                Input
                              </th>
                              <th className="px-6 py-3 text-right font-semibold text-slate-700">
                                Cached
                              </th>
                              <th className="px-6 py-3 text-right font-semibold text-slate-700">
                                Output
                              </th>
                              <th className="px-6 py-3 text-right font-semibold text-slate-700">
                                Total
                              </th>
                              <th className="px-6 py-3 text-right font-semibold text-slate-700">
                                vs Cheapest
                              </th>
                            </tr>
                          </thead>
                          <tbody>
                            {allModelsCosts
                              .sort((a, b) => a.totalCost - b.totalCost)
                              .map((modelCost) => {
                                const cheapest = Math.min(
                                  ...allModelsCosts.map((m) => m.totalCost)
                                );
                                const diff = modelCost.totalCost - cheapest;
                                const diffPercent =
                                  cheapest > 0 ? (diff / cheapest) * 100 : 0;
                                const isSelected =
                                  modelCost.modelId === selectedModel;

                                return (
                                  <tr
                                    key={modelCost.modelId}
                                    className={`border-t border-slate-100 ${
                                      isSelected
                                        ? "bg-blue-50"
                                        : "hover:bg-slate-50"
                                    }`}
                                  >
                                    <td
                                      className={`px-6 py-3 font-medium ${
                                        isSelected
                                          ? "text-blue-700"
                                          : "text-slate-900"
                                      }`}
                                    >
                                      {modelCost.model}
                                      {isSelected && (
                                        <span className="ml-2 text-xs text-blue-600">
                                          ●
                                        </span>
                                      )}
                                    </td>
                                    <td className="px-6 py-3 text-right text-slate-600">
                                      ${modelCost.totalInputCost.toFixed(2)}
                                    </td>
                                    <td className="px-6 py-3 text-right text-slate-600">
                                      ${modelCost.totalCachedCost.toFixed(2)}
                                    </td>
                                    <td className="px-6 py-3 text-right text-slate-600">
                                      ${modelCost.totalOutputCost.toFixed(2)}
                                    </td>
                                    <td className="px-6 py-3 text-right font-bold text-slate-900">
                                      ${modelCost.totalCost.toFixed(2)}
                                    </td>
                                    <td className="px-6 py-3 text-right">
                                      {diff === 0 ? (
                                        <span className="text-green-600 font-semibold">
                                          Best
                                        </span>
                                      ) : (
                                        <span className="text-amber-600">
                                          +${diff.toFixed(2)} (
                                          {diffPercent.toFixed(0)}%)
                                        </span>
                                      )}
                                    </td>
                                  </tr>
                                );
                              })}
                          </tbody>
                        </table>
                      </div>
                    </div>

                    {/* Insights */}
                    <div className="bg-gradient-to-r from-indigo-50 to-blue-50 border border-indigo-200 rounded-lg p-6">
                      <h4 className="font-semibold text-indigo-900 mb-3 flex items-center gap-2">
                        <svg
                          width="20"
                          height="20"
                          viewBox="0 0 24 24"
                          fill="none"
                          stroke="currentColor"
                          strokeWidth="2"
                          strokeLinecap="round"
                          strokeLinejoin="round"
                        >
                          <circle cx="12" cy="12" r="10" />
                          <line x1="12" y1="16" x2="12" y2="12" />
                          <line x1="12" y1="8" x2="12.01" y2="8" />
                        </svg>
                        Cost Insights
                      </h4>
                      <div className="space-y-2 text-sm text-indigo-800">
                        {(() => {
                          const cheapestAI = allModelsCosts.reduce((min, m) =>
                            m.totalCost < min.totalCost ? m : min
                          );
                          const current = allModelsCosts.find(
                            (m) => m.modelId === selectedModel
                          );
                          const savingsVsCurrent = current
                            ? current.totalCost - cheapestAI.totalCost
                            : 0;
                          const trainedCost = costBreakdown.trainedModelCost;

                          return (
                            <>
                              {/* AI Model to AI Model comparison */}
                              {savingsVsCurrent > 0 && (
                                <p>
                                  💡 Switching to{" "}
                                  <strong>{cheapestAI.model}</strong> could save
                                  you{" "}
                                  <strong>
                                    ${savingsVsCurrent.toFixed(2)}/month
                                  </strong>{" "}
                                  (
                                  {(
                                    (savingsVsCurrent / current.totalCost) *
                                    100
                                  ).toFixed(0)}
                                  % reduction) compared to {current.model}.
                                </p>
                              )}
                              {savingsVsCurrent === 0 && (
                                <p>
                                  ✓ You're already using the most cost-effective
                                  AI model for your usage!
                                </p>
                              )}

                              {/* AI vs Trained Documents comparison */}
                              {settings.showTrainedModelComparison &&
                                costBreakdown.totalPages > 0 && (
                                  <>
                                    {cheapestAI.totalCost < trainedCost && (
                                      <p>
                                        🎯{" "}
                                        <strong>
                                          AI Extraction is cheaper!
                                        </strong>{" "}
                                        The best AI model ({cheapestAI.model})
                                        saves{" "}
                                        <strong>
                                          $
                                          {(
                                            trainedCost - cheapestAI.totalCost
                                          ).toFixed(2)}
                                          /month
                                        </strong>{" "}
                                        (
                                        {(
                                          ((trainedCost -
                                            cheapestAI.totalCost) /
                                            trainedCost) *
                                          100
                                        ).toFixed(0)}
                                        % savings) vs. Trained Documents Model.
                                      </p>
                                    )}
                                    {cheapestAI.totalCost > trainedCost && (
                                      <p>
                                        ⚠️ Trained Documents Model is currently
                                        cheaper by{" "}
                                        <strong>
                                          $
                                          {(
                                            cheapestAI.totalCost - trainedCost
                                          ).toFixed(2)}
                                          /month
                                        </strong>
                                        . Consider scale, flexibility, and
                                        maintenance costs when deciding.
                                      </p>
                                    )}
                                    {cheapestAI.totalCost === trainedCost && (
                                      <p>
                                        ⚖️ AI and Trained Documents have
                                        identical operational costs at this
                                        volume.
                                      </p>
                                    )}
                                  </>
                                )}

                              <p>
                                📊 AI model costs range from{" "}
                                <strong>
                                  $
                                  {Math.min(
                                    ...allModelsCosts.map((m) => m.totalCost)
                                  ).toFixed(2)}
                                </strong>{" "}
                                to{" "}
                                <strong>
                                  $
                                  {Math.max(
                                    ...allModelsCosts.map((m) => m.totalCost)
                                  ).toFixed(2)}
                                </strong>{" "}
                                per month.
                              </p>
                            </>
                          );
                        })()}
                      </div>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}

        {/* Help Modal */}
        {helpOpen && (
          <div
            className="fixed inset-0 bg-black bg-opacity-50 flex items-start justify-center p-4 z-50 overflow-y-auto"
            onClick={() => setHelpOpen(false)}
          >
            <div
              className="bg-white rounded-lg shadow-xl max-w-2xl w-full my-8"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between rounded-t-lg sticky top-0 z-10">
                <h3 className="text-lg font-bold text-slate-900">
                  Help & Guide
                </h3>
                <button
                  onClick={() => setHelpOpen(false)}
                  className="p-2 hover:bg-slate-100 rounded transition-colors flex-shrink-0"
                  title="Close"
                >
                  <X className="text-slate-600" size={20} />
                </button>
              </div>
              <div
                className="p-6 overflow-y-auto"
                style={{ maxHeight: "calc(90vh - 80px)" }}
              >
                <div className="space-y-4">
                  <div className="bg-gradient-to-r from-blue-50 to-indigo-50 border border-blue-200 rounded-lg p-4">
                    <h4 className="font-semibold text-blue-900 mb-3 flex items-center gap-2">
                      <svg
                        width="20"
                        height="20"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      >
                        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                        <polyline points="14 2 14 8 20 8" />
                        <line x1="16" y1="13" x2="8" y2="13" />
                        <line x1="16" y1="17" x2="8" y2="17" />
                        <polyline points="10 9 9 9 8 9" />
                      </svg>
                      How to Use This Calculator
                    </h4>
                    <div className="space-y-3 text-sm text-blue-900">
                      <div className="flex gap-3">
                        <div className="flex-shrink-0 w-6 h-6 bg-blue-600 text-white rounded-full flex items-center justify-center font-bold text-xs">
                          1
                        </div>
                        <div>
                          <strong>Select your AI model</strong> from the
                          dropdown (GPT-4, Gemini, etc.)
                        </div>
                      </div>
                      <div className="flex gap-3">
                        <div className="flex-shrink-0 w-6 h-6 bg-blue-600 text-white rounded-full flex items-center justify-center font-bold text-xs">
                          2
                        </div>
                        <div>
                          <strong>Enter monthly document quantities</strong> for
                          each size category (S, M, L, XL) based on your
                          expected volume
                        </div>
                      </div>
                      <div className="flex gap-3">
                        <div className="flex-shrink-0 w-6 h-6 bg-blue-600 text-white rounded-full flex items-center justify-center font-bold text-xs">
                          3
                        </div>
                        <div>
                          <strong>Review the cost comparison</strong> on the
                          right (or below in mobile view) to see AI Extraction
                          vs. Trained Documents Model
                        </div>
                      </div>
                      <div className="flex gap-3">
                        <div className="flex-shrink-0 w-6 h-6 bg-blue-600 text-white rounded-full flex items-center justify-center font-bold text-xs">
                          4
                        </div>
                        <div>
                          <strong>Switch view mode</strong> using the 📱/🖥️ icon
                          to preview in mobile or desktop layout
                        </div>
                      </div>
                      <div className="flex gap-3">
                        <div className="flex-shrink-0 w-6 h-6 bg-blue-600 text-white rounded-full flex items-center justify-center font-bold text-xs">
                          5
                        </div>
                        <div>
                          <strong>Adjust advanced settings</strong> (⚙️ icon) if
                          you need to customize pricing, prompts, or document
                          assumptions
                        </div>
                      </div>
                    </div>
                  </div>

                  <div className="bg-gradient-to-r from-green-50 to-emerald-50 border border-green-200 rounded-lg p-4">
                    <h4 className="font-semibold text-green-900 mb-2 flex items-center gap-2">
                      <svg
                        width="18"
                        height="18"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      >
                        <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
                        <polyline points="22 4 12 14.01 9 11.01" />
                      </svg>
                      What You'll Get
                    </h4>
                    <ul className="space-y-2 text-sm text-green-900">
                      <li className="flex gap-2">
                        <span className="text-green-600">✓</span>
                        <span>
                          <strong>Cost ranges</strong> showing estimated min-max
                          monthly costs (±20% by default)
                        </span>
                      </li>
                      <li className="flex gap-2">
                        <span className="text-green-600">✓</span>
                        <span>
                          <strong>Direct comparison</strong> between AI
                          Extraction and Trained Documents Model
                        </span>
                      </li>
                      <li className="flex gap-2">
                        <span className="text-green-600">✓</span>
                        <span>
                          <strong>Percentage difference</strong> showing
                          potential savings or additional costs
                        </span>
                      </li>
                      <li className="flex gap-2">
                        <span className="text-green-600">✓</span>
                        <span>
                          <strong>Detailed breakdowns</strong> of
                          classification, extraction, cached, and output costs
                        </span>
                      </li>
                      <li className="flex gap-2">
                        <span className="text-green-600">✓</span>
                        <span>
                          <strong>Multi-model comparison</strong> to find the
                          most cost-effective AI model for your needs
                        </span>
                      </li>
                      <li className="flex gap-2">
                        <span className="text-green-600">✓</span>
                        <span>
                          <strong>Responsive preview</strong> with
                          mobile/desktop view toggle for testing different
                          layouts
                        </span>
                      </li>
                    </ul>
                  </div>

                  <div className="bg-purple-50 border border-purple-200 rounded-lg p-4">
                    <h4 className="font-semibold text-purple-900 mb-2 flex items-center gap-2">
                      <svg
                        width="18"
                        height="18"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      >
                        <rect
                          x="5"
                          y="2"
                          width="14"
                          height="20"
                          rx="2"
                          ry="2"
                        />
                        <line x1="12" y1="18" x2="12.01" y2="18" />
                      </svg>
                      View Modes
                    </h4>
                    <div className="space-y-2 text-sm text-purple-900">
                      <p>
                        <strong>Desktop View (🖥️):</strong> Full-width layout
                        with side-by-side columns for document quantities and
                        cost summary. Ideal for detailed analysis on larger
                        screens.
                      </p>
                      <p>
                        <strong>Mobile View (📱):</strong> Compact single-column
                        layout optimized for smaller screens. Perfect for quick
                        checks on mobile devices or when screen space is
                        limited.
                      </p>
                      <p className="text-xs italic text-purple-700 mt-2">
                        💡 Your view preference is automatically saved and
                        restored when you return.
                      </p>
                    </div>
                  </div>

                  <div>
                    <h4 className="font-semibold text-slate-900 mb-2">
                      Overview
                    </h4>
                    <p className="text-sm text-slate-600">
                      The calculator estimates costs based on a two-step AI
                      workflow: <strong>Classification</strong> (determining
                      document type) and <strong>Extraction</strong> (extracting
                      specific fields). Each document goes through both steps,
                      consuming tokens at each stage.
                    </p>
                  </div>

                  <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                    <h4 className="font-semibold text-blue-900 mb-3 flex items-center gap-2">
                      <svg
                        width="18"
                        height="18"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      >
                        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                        <polyline points="14 2 14 8 20 8" />
                        <line x1="16" y1="13" x2="8" y2="13" />
                        <line x1="16" y1="17" x2="8" y2="17" />
                        <polyline points="10 9 9 9 8 9" />
                      </svg>
                      Two-Step Process
                    </h4>
                    <div className="space-y-3 text-sm text-slate-700">
                      <div className="bg-white rounded p-3 border border-blue-200">
                        <div className="font-semibold text-blue-800 mb-1">
                          Step 1: Classification
                        </div>
                        <p className="text-xs text-slate-600">
                          The AI first analyzes the document to determine its
                          type (e.g., invoice, contract, statement). This helps
                          route it to the appropriate extraction template.
                        </p>
                        <div className="mt-2 text-xs">
                          <strong>Tokens used:</strong> Classification prompt +
                          Document content
                          <br />
                          <strong>Output:</strong> Negligible (just the document
                          type)
                        </div>
                      </div>
                      <div className="bg-white rounded p-3 border border-blue-200">
                        <div className="font-semibold text-green-800 mb-1">
                          Step 2: Extraction
                        </div>
                        <p className="text-xs text-slate-600">
                          Based on the document type, the AI extracts specific
                          fields (names, dates, amounts, etc.) using a
                          specialized extraction prompt.
                        </p>
                        <div className="mt-2 text-xs">
                          <strong>Input tokens:</strong> Extraction prompt +
                          Document content
                          <br />
                          <strong>Cached tokens:</strong> Reusable portions of
                          extraction prompt (if enabled)
                          <br />
                          <strong>Output tokens:</strong> Extracted fields data
                        </div>
                      </div>
                    </div>
                  </div>

                  <div>
                    <h4 className="font-semibold text-slate-900 mb-2">
                      Token Calculation Per Document
                    </h4>
                    <div className="bg-slate-50 p-4 rounded-lg space-y-3 text-sm font-mono">
                      <div>
                        <strong>Document Tokens:</strong>
                        <div className="text-slate-600 ml-4">
                          avg_pages × tokens_per_page
                        </div>
                        <div className="text-xs text-slate-500 ml-4 mt-1">
                          Example: 10 pages × 700 tokens/page = 7,000 tokens
                        </div>
                      </div>

                      <div className="pt-2 border-t border-slate-300">
                        <strong>Classification Tokens:</strong>
                        <div className="text-slate-600 ml-4">
                          classification_prompt_tokens + document_tokens
                        </div>
                        <div className="text-xs text-slate-500 ml-4 mt-1">
                          Example: 500 + 7,000 = 7,500 tokens
                        </div>
                      </div>

                      <div className="pt-2 border-t border-slate-300">
                        <strong>Extraction Input Tokens:</strong>
                        <div className="text-slate-600 ml-4">
                          extraction_prompt_input_tokens + document_tokens
                        </div>
                        <div className="text-xs text-slate-500 ml-4 mt-1">
                          Example: 105,000 + 7,000 = 112,000 tokens
                        </div>
                      </div>

                      <div className="pt-2 border-t border-slate-300">
                        <strong>Extraction Cached Tokens:</strong>
                        <div className="text-slate-600 ml-4">
                          extraction_prompt_cached_tokens
                        </div>
                        <div className="text-xs text-slate-500 ml-4 mt-1">
                          Reusable portions of the extraction prompt (lower
                          cost)
                        </div>
                      </div>

                      <div className="pt-2 border-t border-slate-300">
                        <strong>Output Tokens:</strong>
                        <div className="text-slate-600 ml-4">
                          extracted_fields × tokens_per_field
                        </div>
                        <div className="text-xs text-slate-500 ml-4 mt-1">
                          Example: 30 fields × 10 tokens/field = 300 tokens
                        </div>
                      </div>
                    </div>
                  </div>

                  <div>
                    <h4 className="font-semibold text-slate-900 mb-2">
                      Monthly Cost Calculation
                    </h4>
                    <div className="bg-slate-50 p-4 rounded-lg space-y-3 text-sm font-mono">
                      <div>
                        <strong>Classification Cost:</strong>
                        <div className="text-slate-600 ml-4">
                          (monthly_classification_tokens ÷ 1,000,000) ×
                          input_price
                        </div>
                        <div className="text-xs text-slate-500 ml-4 mt-1">
                          Sum across all document profiles and quantities
                        </div>
                      </div>
                      <div>
                        <strong>Extraction Input Cost:</strong>
                        <div className="text-slate-600 ml-4">
                          (monthly_extraction_input_tokens ÷ 1,000,000) ×
                          input_price
                        </div>
                      </div>
                      <div>
                        <strong>Cached Cost:</strong>
                        <div className="text-slate-600 ml-4">
                          (monthly_cached_tokens ÷ 1,000,000) × cached_price
                        </div>
                        <div className="text-xs text-slate-500 ml-4 mt-1">
                          Cached tokens are typically cheaper than input tokens
                        </div>
                      </div>
                      <div>
                        <strong>Output Cost:</strong>
                        <div className="text-slate-600 ml-4">
                          (monthly_output_tokens ÷ 1,000,000) × output_price
                        </div>
                      </div>
                      <div className="pt-2 border-t border-slate-300">
                        <strong>Total Monthly Cost:</strong>
                        <div className="text-slate-600 ml-4">
                          classification_cost + extraction_input_cost +
                          cached_cost + output_cost
                        </div>
                      </div>
                    </div>
                  </div>

                  <div className="bg-amber-50 border border-amber-200 rounded-lg p-4">
                    <h4 className="font-semibold text-amber-900 mb-2">
                      Example Calculation
                    </h4>
                    <div className="text-sm text-amber-800 space-y-2">
                      <p>
                        <strong>Scenario:</strong> 100 medium documents/month
                        (10 pages each)
                      </p>
                      <div className="bg-white rounded p-3 space-y-1 text-xs font-mono">
                        <div>
                          <strong>Document tokens:</strong> 10 pages × 700 =
                          7,000 tokens
                        </div>
                        <div className="text-blue-700">
                          <strong>Classification:</strong> (500 + 7,000) × 100 =
                          750,000 tokens
                        </div>
                        <div className="text-green-700">
                          <strong>Extraction input:</strong> (35,000 + 7,000) ×
                          100 = 4,200,000 tokens
                        </div>
                        <div className="text-purple-700">
                          <strong>Extraction cached:</strong> 0 × 100 = 0 tokens
                        </div>
                        <div className="text-orange-700">
                          <strong>Output:</strong> 300 × 100 = 30,000 tokens
                        </div>
                        <div className="pt-2 border-t border-amber-200 mt-2">
                          <strong>
                            At $1.966/1M input, $1.035/1M cached, $7.87/1M
                            output:
                          </strong>
                        </div>
                        <div>Classification: 0.75M × $1.966 = $1.47</div>
                        <div>Extraction input: 4.2M × $1.966 = $8.26</div>
                        <div>Cached: 0M × $1.035 = $0.00</div>
                        <div>Output: 0.03M × $7.87 = $0.24</div>
                        <div className="font-bold pt-1 border-t border-amber-300 mt-1">
                          Total: $9.97/month
                        </div>
                      </div>
                    </div>
                  </div>

                  <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                    <p className="text-sm text-blue-900">
                      <strong>💡 Tip:</strong> Click "Show calculation" in the
                      Monthly Cost Comparison panel to see the detailed
                      breakdown for your specific inputs. You can also customize
                      all assumptions in the Advanced Settings, including prompt
                      configurations for both classification and extraction
                      steps.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Settings Modal */}
        {settingsOpen && (
          <div
            className="fixed inset-0 bg-black bg-opacity-50 flex items-start justify-center p-4 z-50 overflow-y-auto"
            onClick={() => setSettingsOpen(false)}
          >
            <div
              className="bg-white rounded-lg shadow-xl max-w-4xl w-full my-8"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between rounded-t-lg sticky top-0 z-10">
                <h3 className="text-lg font-bold text-slate-900">
                  Advanced Settings
                </h3>
                <button
                  onClick={() => setSettingsOpen(false)}
                  className="p-2 hover:bg-slate-100 rounded transition-colors flex-shrink-0"
                  title="Close"
                >
                  <X className="text-slate-600" size={20} />
                </button>
              </div>

              <div
                className="p-6 space-y-6 overflow-y-auto"
                style={{ maxHeight: "calc(90vh - 80px)" }}
              >
                {/* Model Pricing */}
                <div className="border border-slate-200 rounded-lg">
                  <button
                    onClick={() => setPricingOpen(!pricingOpen)}
                    className="w-full px-4 py-3 flex items-center justify-between hover:bg-slate-50 transition-colors rounded-t-lg"
                  >
                    <h4 className="font-semibold text-slate-900">
                      Model Pricing ($ per 1M tokens)
                    </h4>
                    {pricingOpen ? (
                      <ChevronUp className="text-slate-400" size={20} />
                    ) : (
                      <ChevronDown className="text-slate-400" size={20} />
                    )}
                  </button>

                  {pricingOpen && (
                    <div className="px-4 pb-4 pt-2 border-t border-slate-200">
                      <div className="overflow-x-auto">
                        <table className="w-full text-sm">
                          <thead className="bg-slate-50">
                            <tr>
                              <th className="px-4 py-2 text-left text-slate-700">
                                Model Name
                              </th>
                              <th className="px-4 py-2 text-right text-slate-700">
                                Input
                              </th>
                              <th className="px-4 py-2 text-right text-slate-700">
                                Cached
                              </th>
                              <th className="px-4 py-2 text-right text-slate-700">
                                Output
                              </th>
                              <th className="px-4 py-2 text-center text-slate-700">
                                Actions
                              </th>
                            </tr>
                          </thead>
                          <tbody>
                            {models.map((model) => (
                              <tr
                                key={model.id}
                                className="border-t border-slate-100"
                              >
                                <td className="px-4 py-3">
                                  <input
                                    type="text"
                                    value={model.name}
                                    onChange={(e) =>
                                      updateModelName(model.id, e.target.value)
                                    }
                                    className="w-full px-2 py-1 border border-slate-300 rounded text-sm"
                                  />
                                </td>
                                <td className="px-4 py-3">
                                  <input
                                    type="number"
                                    min="0"
                                    step="0.1"
                                    value={model.inputPrice}
                                    onChange={(e) =>
                                      updateModelPrice(
                                        model.id,
                                        "inputPrice",
                                        e.target.value
                                      )
                                    }
                                    className="w-20 px-2 py-1 border border-slate-300 rounded text-right text-sm"
                                  />
                                </td>
                                <td className="px-4 py-3">
                                  <input
                                    type="number"
                                    min="0"
                                    step="0.1"
                                    value={model.cachedPrice}
                                    onChange={(e) =>
                                      updateModelPrice(
                                        model.id,
                                        "cachedPrice",
                                        e.target.value
                                      )
                                    }
                                    className="w-20 px-2 py-1 border border-slate-300 rounded text-right text-sm"
                                  />
                                </td>
                                <td className="px-4 py-3">
                                  <input
                                    type="number"
                                    min="0"
                                    step="0.1"
                                    value={model.outputPrice}
                                    onChange={(e) =>
                                      updateModelPrice(
                                        model.id,
                                        "outputPrice",
                                        e.target.value
                                      )
                                    }
                                    className="w-20 px-2 py-1 border border-slate-300 rounded text-right text-sm"
                                  />
                                </td>
                                <td className="px-4 py-3 text-center">
                                  <button
                                    onClick={() => deleteModel(model.id)}
                                    className="text-red-600 hover:text-red-800 text-sm"
                                    title="Delete model"
                                  >
                                    Delete
                                  </button>
                                </td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                      <button
                        onClick={addNewModel}
                        className="mt-3 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg text-sm transition-colors"
                      >
                        + Add Model
                      </button>
                    </div>
                  )}
                </div>

                {/* Prompt Configuration */}
                <div className="border border-slate-200 rounded-lg">
                  <button
                    onClick={() => setPromptConfigOpen(!promptConfigOpen)}
                    className="w-full px-4 py-3 flex items-center justify-between hover:bg-slate-50 transition-colors rounded-t-lg"
                  >
                    <h4 className="font-semibold text-slate-900">
                      Prompt Configuration
                    </h4>
                    {promptConfigOpen ? (
                      <ChevronUp className="text-slate-400" size={20} />
                    ) : (
                      <ChevronDown className="text-slate-400" size={20} />
                    )}
                  </button>

                  {promptConfigOpen && (
                    <div className="px-4 pb-4 pt-2 border-t border-slate-200 space-y-4">
                      {/* Radio buttons */}
                      <div className="space-y-3">
                        <label
                          className="flex items-center gap-3 p-3 border-2 rounded-lg cursor-pointer hover:bg-slate-50 transition-colors"
                          style={{
                            borderColor:
                              settings.promptType === "standard"
                                ? "#3b82f6"
                                : "#e2e8f0",
                          }}
                        >
                          <input
                            type="radio"
                            name="promptType"
                            value="standard"
                            checked={settings.promptType === "standard"}
                            onChange={(e) =>
                              updateSetting("promptType", e.target.value)
                            }
                            className="w-4 h-4 text-blue-600"
                          />
                          <div className="flex-1">
                            <div className="font-medium text-slate-900">
                              Standard Default Prompt
                            </div>
                            <div className="text-xs text-slate-500 mt-0.5">
                              Uses the default KPMG prompt
                            </div>
                          </div>
                        </label>

                        <label
                          className="flex items-center gap-3 p-3 border-2 rounded-lg cursor-pointer hover:bg-slate-50 transition-colors"
                          style={{
                            borderColor:
                              settings.promptType === "custom"
                                ? "#3b82f6"
                                : "#e2e8f0",
                          }}
                        >
                          <input
                            type="radio"
                            name="promptType"
                            value="custom"
                            checked={settings.promptType === "custom"}
                            onChange={(e) =>
                              updateSetting("promptType", e.target.value)
                            }
                            className="w-4 h-4 text-blue-600"
                          />
                          <div className="flex-1">
                            <div className="font-medium text-slate-900">
                              Custom Prompt
                            </div>
                            <div className="text-xs text-slate-500 mt-0.5">
                              Define your own prompt token counts
                            </div>
                          </div>
                        </label>
                      </div>

                      {/* Input fields based on selection */}
                      {settings.promptType === "standard" ? (
                        <div className="space-y-4">
                          <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                            <h5 className="text-sm font-semibold text-blue-900 mb-3">
                              Classification Prompt
                            </h5>
                            <div>
                              <label className="block text-sm text-slate-600 mb-1">
                                Classification Prompt Input Tokens
                              </label>
                              <input
                                type="number"
                                min="0"
                                value={
                                  settings.standardClassificationPromptInputTokens
                                }
                                onClick={(e) => {
                                  const confirmed = window.confirm(
                                    "⚠️ Warning: This should only be edited by KPMG personnel. If you changed your prompt, use Custom instead.\n\nDo you want to continue editing the Standard Default Prompt?"
                                  );
                                  if (!confirmed) {
                                    e.target.blur();
                                  }
                                }}
                                onChange={(e) =>
                                  updateSetting(
                                    "standardClassificationPromptInputTokens",
                                    parseFloat(e.target.value) || 0
                                  )
                                }
                                className="w-full px-3 py-2 border border-slate-300 rounded"
                              />
                              <p className="text-xs text-slate-500 mt-1">
                                Prompt tokens for document classification
                                (document tokens added automatically)
                              </p>
                            </div>
                          </div>

                          <div className="bg-green-50 border border-green-200 rounded-lg p-4">
                            <h5 className="text-sm font-semibold text-green-900 mb-3">
                              Extraction Prompt
                            </h5>
                            <div className="grid md:grid-cols-2 gap-4">
                              <div>
                                <label className="block text-sm text-slate-600 mb-1">
                                  Extraction Prompt Input Tokens
                                </label>
                                <input
                                  type="number"
                                  min="0"
                                  value={
                                    settings.standardExtractionPromptInputTokens
                                  }
                                  onClick={(e) => {
                                    const confirmed = window.confirm(
                                      "⚠️ Warning: This should only be edited by KPMG personnel. If you changed your prompt, use Custom instead.\n\nDo you want to continue editing the Standard Default Prompt?"
                                    );
                                    if (!confirmed) {
                                      e.target.blur();
                                    }
                                  }}
                                  onChange={(e) =>
                                    updateSetting(
                                      "standardExtractionPromptInputTokens",
                                      parseFloat(e.target.value) || 0
                                    )
                                  }
                                  className="w-full px-3 py-2 border border-slate-300 rounded"
                                />
                                <p className="text-xs text-slate-500 mt-1">
                                  Non-cacheable prompt tokens
                                </p>
                              </div>
                              <div>
                                <label className="block text-sm text-slate-600 mb-1">
                                  Extraction Prompt Cached Tokens
                                </label>
                                <input
                                  type="number"
                                  min="0"
                                  value={
                                    settings.standardExtractionPromptCachedTokens
                                  }
                                  onClick={(e) => {
                                    const confirmed = window.confirm(
                                      "⚠️ Warning: This should only be edited by KPMG personnel. If you changed your prompt, use Custom instead.\n\nDo you want to continue editing the Standard Default Prompt?"
                                    );
                                    if (!confirmed) {
                                      e.target.blur();
                                    }
                                  }}
                                  onChange={(e) =>
                                    updateSetting(
                                      "standardExtractionPromptCachedTokens",
                                      parseFloat(e.target.value) || 0
                                    )
                                  }
                                  className="w-full px-3 py-2 border border-slate-300 rounded"
                                />
                                <p className="text-xs text-slate-500 mt-1">
                                  Cacheable prompt tokens
                                </p>
                              </div>
                            </div>
                          </div>

                          <div className="text-xs text-amber-600 flex items-start gap-1">
                            <span className="flex-shrink-0">⚠️</span>
                            <span>
                              These values should only be edited by KPMG
                              personnel
                            </span>
                          </div>
                        </div>
                      ) : (
                        <div className="space-y-4">
                          <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                            <h5 className="text-sm font-semibold text-blue-900 mb-3">
                              Classification Prompt
                            </h5>
                            <div>
                              <label className="block text-sm text-slate-600 mb-1">
                                Custom Classification Prompt Input Tokens
                              </label>
                              <input
                                type="number"
                                min="0"
                                value={
                                  settings.customClassificationPromptInputTokens
                                }
                                onChange={(e) =>
                                  updateSetting(
                                    "customClassificationPromptInputTokens",
                                    parseFloat(e.target.value) || 0
                                  )
                                }
                                placeholder="Enter token count"
                                className="w-full px-3 py-2 border border-slate-300 rounded"
                              />
                              <p className="text-xs text-slate-500 mt-1">
                                Prompt tokens for document classification
                                (document tokens added automatically)
                              </p>
                            </div>
                          </div>

                          <div className="bg-green-50 border border-green-200 rounded-lg p-4">
                            <h5 className="text-sm font-semibold text-green-900 mb-3">
                              Extraction Prompt
                            </h5>
                            <div className="grid md:grid-cols-2 gap-4">
                              <div>
                                <label className="block text-sm text-slate-600 mb-1">
                                  Custom Extraction Prompt Input Tokens
                                </label>
                                <input
                                  type="number"
                                  min="0"
                                  value={
                                    settings.customExtractionPromptInputTokens
                                  }
                                  onChange={(e) =>
                                    updateSetting(
                                      "customExtractionPromptInputTokens",
                                      parseFloat(e.target.value) || 0
                                    )
                                  }
                                  placeholder="Enter token count"
                                  className="w-full px-3 py-2 border border-slate-300 rounded"
                                />
                                <p className="text-xs text-slate-500 mt-1">
                                  Non-cacheable prompt tokens
                                </p>
                              </div>
                              <div>
                                <label className="block text-sm text-slate-600 mb-1">
                                  Custom Extraction Prompt Cached Tokens
                                </label>
                                <input
                                  type="number"
                                  min="0"
                                  value={
                                    settings.customExtractionPromptCachedTokens
                                  }
                                  onChange={(e) =>
                                    updateSetting(
                                      "customExtractionPromptCachedTokens",
                                      parseFloat(e.target.value) || 0
                                    )
                                  }
                                  placeholder="Enter token count"
                                  className="w-full px-3 py-2 border border-slate-300 rounded"
                                />
                                <p className="text-xs text-slate-500 mt-1">
                                  Cacheable prompt tokens (lower cost)
                                </p>
                              </div>
                            </div>
                          </div>
                        </div>
                      )}
                    </div>
                  )}
                </div>

                {/* Profile Settings */}
                <div className="border border-slate-200 rounded-lg">
                  <button
                    onClick={() => setProfilesOpen(!profilesOpen)}
                    className="w-full px-4 py-3 flex items-center justify-between hover:bg-slate-50 transition-colors rounded-t-lg"
                  >
                    <h4 className="font-semibold text-slate-900">
                      Document Size Assumptions
                    </h4>
                    {profilesOpen ? (
                      <ChevronUp className="text-slate-400" size={20} />
                    ) : (
                      <ChevronDown className="text-slate-400" size={20} />
                    )}
                  </button>

                  {profilesOpen && (
                    <div className="px-4 pb-4 pt-2 border-t border-slate-200 space-y-3">
                      {Object.entries(profiles).map(([key, profile]) => (
                        <div
                          key={key}
                          className="flex items-center gap-4 p-3 bg-slate-50 rounded-lg"
                        >
                          <div className="w-12 text-center font-bold text-slate-700">
                            {key}
                          </div>
                          <div className="flex-1">
                            <div className="text-sm font-medium text-slate-700">
                              {profile.label} ({profile.pageRange})
                            </div>
                          </div>
                          <div className="flex items-center gap-2">
                            <label className="text-xs text-slate-600">
                              Avg pages:
                            </label>
                            <input
                              type="number"
                              min="1"
                              value={profile.avgPages}
                              onChange={(e) =>
                                updateProfile(key, "avgPages", e.target.value)
                              }
                              className="w-20 px-2 py-1 border border-slate-300 rounded text-right text-sm"
                            />
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                {/* General Settings */}
                <div className="border border-slate-200 rounded-lg">
                  <button
                    onClick={() => setExtractionOpen(!extractionOpen)}
                    className="w-full px-4 py-3 flex items-center justify-between hover:bg-slate-50 transition-colors rounded-t-lg"
                  >
                    <h4 className="font-semibold text-slate-900">
                      Extraction Assumptions
                    </h4>
                    {extractionOpen ? (
                      <ChevronUp className="text-slate-400" size={20} />
                    ) : (
                      <ChevronDown className="text-slate-400" size={20} />
                    )}
                  </button>

                  {extractionOpen && (
                    <div className="px-4 pb-4 pt-2 border-t border-slate-200">
                      <div className="grid md:grid-cols-2 gap-4">
                        <div>
                          <label className="block text-sm text-slate-600 mb-1">
                            Tokens per page
                          </label>
                          <input
                            type="number"
                            min="0"
                            value={settings.tokensPerPage}
                            onChange={(e) =>
                              updateSetting(
                                "tokensPerPage",
                                parseFloat(e.target.value) || 0
                              )
                            }
                            className="w-full px-3 py-2 border border-slate-300 rounded"
                          />
                        </div>
                        <div>
                          <label className="block text-sm text-slate-600 mb-1">
                            Extracted fields per document
                          </label>
                          <input
                            type="number"
                            min="0"
                            value={settings.extractedFields}
                            onChange={(e) =>
                              updateSetting(
                                "extractedFields",
                                parseFloat(e.target.value) || 0
                              )
                            }
                            className="w-full px-3 py-2 border border-slate-300 rounded"
                          />
                        </div>
                        <div>
                          <label className="block text-sm text-slate-600 mb-1">
                            Tokens per field
                          </label>
                          <input
                            type="number"
                            min="0"
                            value={settings.tokensPerField}
                            onChange={(e) =>
                              updateSetting(
                                "tokensPerField",
                                parseFloat(e.target.value) || 0
                              )
                            }
                            className="w-full px-3 py-2 border border-slate-300 rounded"
                          />
                        </div>
                      </div>
                    </div>
                  )}
                </div>

                {/* Trained Documents Model */}
                <div className="border border-slate-200 rounded-lg">
                  <button
                    onClick={() => setTrainedModelOpen(!trainedModelOpen)}
                    className="w-full px-4 py-3 flex items-center justify-between hover:bg-slate-50 transition-colors rounded-t-lg"
                  >
                    <h4 className="font-semibold text-slate-900">
                      Trained Documents Model
                    </h4>
                    {trainedModelOpen ? (
                      <ChevronUp className="text-slate-400" size={20} />
                    ) : (
                      <ChevronDown className="text-slate-400" size={20} />
                    )}
                  </button>

                  {trainedModelOpen && (
                    <div className="px-4 pb-4 pt-2 border-t border-slate-200 space-y-4">
                      {/* Toggle to show/hide comparison */}
                      <div className="flex items-center justify-between p-3 bg-slate-50 rounded-lg">
                        <div>
                          <div className="font-medium text-slate-900">
                            Show comparison
                          </div>
                          <div className="text-xs text-slate-500 mt-0.5">
                            Enable to compare AI models with trained documents
                            approach
                          </div>
                        </div>
                        <button
                          onClick={() =>
                            updateSetting(
                              "showTrainedModelComparison",
                              !settings.showTrainedModelComparison
                            )
                          }
                          className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                            settings.showTrainedModelComparison
                              ? "bg-blue-600"
                              : "bg-slate-300"
                          }`}
                        >
                          <span
                            className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                              settings.showTrainedModelComparison
                                ? "translate-x-6"
                                : "translate-x-1"
                            }`}
                          />
                        </button>
                      </div>

                      {/* Cost input - only show when comparison is enabled */}
                      {settings.showTrainedModelComparison && (
                        <div>
                          <label className="block text-sm text-slate-600 mb-1">
                            Cost per page
                          </label>
                          <input
                            type="number"
                            min="0"
                            step="0.01"
                            value={settings.trainedModelCostPerPage}
                            onChange={(e) =>
                              updateSetting(
                                "trainedModelCostPerPage",
                                parseFloat(e.target.value) || 0
                              )
                            }
                            className="w-full px-3 py-2 border border-slate-300 rounded"
                            placeholder="0.05"
                          />
                          <p className="text-xs text-slate-500 mt-2 italic">
                            This comparison does not include model training or
                            maintenance costs. It only estimates operational
                            cost per processed page.
                          </p>
                        </div>
                      )}
                    </div>
                  )}
                </div>

                {/* Cost Range Settings */}
                <div className="border border-slate-200 rounded-lg">
                  <button
                    onClick={() => setCostRangeOpen(!costRangeOpen)}
                    className="w-full px-4 py-3 flex items-center justify-between hover:bg-slate-50 transition-colors rounded-t-lg"
                  >
                    <h4 className="font-semibold text-slate-900">
                      Cost Range Settings
                    </h4>
                    {costRangeOpen ? (
                      <ChevronUp className="text-slate-400" size={20} />
                    ) : (
                      <ChevronDown className="text-slate-400" size={20} />
                    )}
                  </button>

                  {costRangeOpen && (
                    <div className="px-4 pb-4 pt-2 border-t border-slate-200">
                      <div>
                        <label className="block text-sm text-slate-600 mb-1">
                          Cost variance percentage (±)
                        </label>
                        <div className="flex items-center gap-3">
                          <input
                            type="number"
                            min="0"
                            max="100"
                            step="5"
                            value={settings.costVariancePercentage}
                            onChange={(e) =>
                              updateSetting(
                                "costVariancePercentage",
                                parseFloat(e.target.value) || 0
                              )
                            }
                            className="w-24 px-3 py-2 border border-slate-300 rounded"
                          />
                          <span className="text-sm text-slate-600">%</span>
                        </div>
                        <p className="text-xs text-slate-500 mt-2">
                          Costs will be shown as a range: base cost ±{" "}
                          {settings.costVariancePercentage}%. This accounts for
                          variations in document complexity, token counts, and
                          processing patterns.
                        </p>
                      </div>
                    </div>
                  )}
                </div>

                {/* Reset Button */}
                <div className="pt-4 border-t border-slate-200">
                  <button
                    onClick={resetSettings}
                    className="flex items-center gap-2 px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-lg transition-colors"
                  >
                    <RotateCcw size={16} />
                    Reset Settings to Defaults
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
