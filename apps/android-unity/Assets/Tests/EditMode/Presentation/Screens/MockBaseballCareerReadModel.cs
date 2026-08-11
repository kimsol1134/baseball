using System;
using System.Collections.Generic;
using Baseball.Presentation.Shell;

namespace Baseball.Presentation.Shell
{
    /// <summary>Deterministic EditMode-only screen fixture.</summary>
    public sealed class MockBaseballCareerReadModel : IBaseballCareerReadModel
    {
        private readonly BaseballScreenTemplateReadModel _template;

        public MockBaseballCareerReadModel(IKoreanUiCopyCatalog copy)
        {
            _template = new BaseballScreenTemplateReadModel(copy ?? throw new ArgumentNullException(nameof(copy)));
        }

        public IReadOnlyList<ShellRoute> Routes => _template.Routes;
        public BaseballScreenViewModel Read(ShellRoute route) => _template.Read(route);
    }
}
