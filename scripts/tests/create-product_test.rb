require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'yaml'

class CreateProductTest < Minitest::Test
  REPO_ROOT = File.expand_path('../..', __dir__)

  def setup
    @root = Dir.mktmpdir('create-product-test')
    FileUtils.mkdir_p([File.join(@root, 'scripts'), File.join(@root, 'namespaces/octo')])
    @script = File.join(@root, 'scripts/create-product')
    FileUtils.cp(File.join(REPO_ROOT, 'scripts/create-product'), @script)
    @service_script = File.join(@root, 'scripts/add-service')
    FileUtils.cp(File.join(REPO_ROOT, 'scripts/add-service'), @service_script)
    FileUtils.mkdir_p(File.join(@root, 'charts'))
    FileUtils.cp_r(File.join(REPO_ROOT, 'charts/service-starter'), File.join(@root, 'charts'))
    @product_dir = File.join(@root, 'namespaces/octo/sample')
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def generate(*arguments)
    Open3.capture2e('/bin/bash', @script, '--bu', 'octo', '--product', 'sample',
                   '--team', 'my-github-team', *arguments, chdir: '/')
  end

  def product
    YAML.load_file(File.join(@product_dir, 'product.yaml'))
  end

  def add_service(*arguments)
    Open3.capture2e(RbConfig.ruby, @service_script, '--bu', 'octo', '--product', 'sample',
                   '--service', 'web', *arguments, chdir: '/')
  end

  def test_add_service_uses_declared_namespaces_and_tiers
    assert generate('--environments', 'dev,prod').last.success?
    declaration = product
    declaration['environments'][0]['namespace'] = 'custom-dev'
    declaration['environments'][1]['name'] = 'production'
    declaration['environments'][1]['namespace'] = 'custom-live'
    product_file = File.join(@product_dir, 'product.yaml')
    File.write(product_file, YAML.dump(declaration))
    original = File.binread(product_file)
    output, result = add_service
    assert result.success?, output
    assert_equal original, File.binread(product_file)
    chart = File.join(@product_dir, 'web/deployment')
    assert_equal 'web', YAML.load_file(File.join(chart, 'Chart.yaml'))['name']
    assert_equal 'custom-dev', YAML.load_file(File.join(chart, 'values/nonlive/dev.yaml'))['namespace']
    assert_equal 'custom-live', YAML.load_file(File.join(chart, 'values/live/production.yaml'))['namespace']
  end

  def test_add_service_selected_environments
    assert generate('--environments', 'dev,staging,prod').last.success?
    output, result = add_service('--environments', 'staging,prod')
    assert result.success?, output
    values_dir = File.join(@product_dir, 'web/deployment/values')
    assert_equal ['staging.yaml'], Dir.children(File.join(values_dir, 'nonlive'))
    assert_equal ['prod.yaml'], Dir.children(File.join(values_dir, 'live'))
  end

  def test_add_service_rejects_existing_service_and_symlink
    assert generate('--service', 'web').last.success?
    chart = File.join(@product_dir, 'web/deployment')
    original = File.binread(File.join(chart, 'values.yaml'))
    output, result = add_service
    refute result.success?
    assert_includes output, 'already exists'
    assert_equal original, File.binread(File.join(chart, 'values.yaml'))
    File.symlink(File.join(@root, 'missing'), File.join(@product_dir, 'linked-service'))
    output, result = add_service('--service', 'linked-service')
    refute result.success?
    assert_includes output, 'already exists'
    assert File.symlink?(File.join(@product_dir, 'linked-service'))
  end

  def test_add_service_rejects_missing_product
    output, result = add_service
    refute result.success?
    assert_includes output, 'Product declaration not found'
    refute File.exist?(@product_dir)
  end

  def test_add_service_invalid_arguments_leave_product_unchanged
    assert generate.last.success?
    product_file = File.join(@product_dir, 'product.yaml')
    original = File.binread(product_file)
    [
      ['--service', '../escape'], ['--service', 'Uppercase'], ['--service', 'resources'],
      ['--environments', 'undeclared'], ['--environments', 'dev,dev'],
      ['--environments', 'dev,'], ['--environments', ''], ['--environments', 'dev, prod'],
      ['--unknown'], ['--service'], ['unexpected']
    ].each do |arguments|
      output, result = add_service(*arguments)
      refute result.success?, "Accepted #{arguments.inspect}: #{output}"
      assert_equal original, File.binread(product_file)
      assert_equal ['product.yaml'], Dir.children(@product_dir)
    end
  end

  def test_add_service_validates_product_yaml
    assert generate.last.success?
    declaration = product
    product_file = File.join(@product_dir, 'product.yaml')
    invalid = ["owner: [broken\n", YAML.dump(declaration.merge('product' => 'other')),
               YAML.dump(declaration.merge('environments' => []))]
    %w[name namespace cluster is_production].each do |key|
      broken = YAML.load(YAML.dump(declaration))
      broken['environments'][0][key] = 'invalid/value'
      invalid << YAML.dump(broken)
    end
    invalid << YAML.dump(declaration.merge('environments' => declaration['environments'] * 2))
    invalid.each do |contents|
      File.write(product_file, contents)
      output, result = add_service
      refute result.success?, "Accepted invalid declaration: #{output}"
      assert_equal contents, File.read(product_file)
      refute File.exist?(File.join(@product_dir, 'web'))
    end
  end

  def test_add_service_cleans_up_failed_generation
    assert generate.last.success?
    original = File.binread(File.join(@product_dir, 'product.yaml'))
    FileUtils.remove_entry(File.join(@root, 'charts/service-starter'))
    output, result = add_service
    refute result.success?, output
    refute File.exist?(File.join(@product_dir, 'web'))
    assert_equal original, File.binread(File.join(@product_dir, 'product.yaml'))
  end

  def test_add_service_requires_no_helm
    assert generate.last.success?
    uname = ENV.fetch('PATH').split(File::PATH_SEPARATOR)
               .map { |directory| File.join(directory, 'uname') }
               .find { |path| File.executable?(path) && !File.directory?(path) }
    File.symlink(uname, File.join(@root, 'uname')) if uname
    output, result = Open3.capture2e({ 'PATH' => @root }, RbConfig.ruby, @service_script,
                                   '--bu', 'octo', '--product', 'sample', '--service', 'web')
    assert result.success?, output
    assert File.file?(File.join(@product_dir, 'web/deployment/Chart.yaml'))
  end

  def test_add_service_required_arguments_and_help
    output, result = Open3.capture2e(RbConfig.ruby, @service_script)
    refute result.success?
    assert_includes output, '--bu is required'
    output, result = Open3.capture2e(RbConfig.ruby, @service_script, '--help')
    assert result.success?
    assert_includes output, 'Usage:'
  end

  def test_environment_and_access_mapping
    output, result = generate('--environments', 'dev,staging,prod')
    assert result.success?, output
    assert_equal 'sample', product['product']
    assert_equal 'octo', product['bu']
    assert_equal '#my-github-team', product['owner']['slack']
    assert_equal [
      ['dev', 'container-platform-octo-nonlive', 'sample-dev', false],
      ['staging', 'container-platform-octo-nonlive', 'sample-staging', false],
      ['prod', 'container-platform-octo-live', 'sample-prod', true]
    ], product['environments'].map { |environment| environment.values_at('name', 'cluster', 'namespace', 'is_production') }
    assert_equal %w[edit view], product['access'].map { |access| access['role'] }
    assert_equal [['container-platform-octo-nonlive'], ['container-platform-octo-live']],
                 product['access'].map { |access| access['clusters'] }
  end

  def test_custom_slack_channel
    output, result = generate('--slack', '#integration-hub-team')
    assert result.success?, output
    assert_equal '#integration-hub-team', product['owner']['slack']
    assert_equal 'my-github-team', product['owner']['team']
    assert_equal 'my-github-team', product['access'].first['group']
  end

  def test_slack_channel_without_prefix
    output, result = generate('--slack', 'integration_hub-team')
    assert result.success?, output
    assert_equal '#integration_hub-team', product['owner']['slack']
  end

  def test_default_product_only
    output, result = generate
    assert result.success?, output
    assert_equal ['product.yaml'], Dir.children(@product_dir)
    assert_equal ['dev'], product['environments'].map { |environment| environment['name'] }
    assert_equal ['edit'], product['access'].map { |access| access['role'] }
  end

  def test_production_only
    output, result = generate('--environments', 'prod')
    assert result.success?, output
    assert_equal ['view'], product['access'].map { |access| access['role'] }
    assert_equal ['container-platform-octo-live'], product['access'].first['clusters']
  end

  def test_existing_product_is_unchanged
    assert generate.last.success?
    original = File.binread(File.join(@product_dir, 'product.yaml'))
    output, result = generate
    refute result.success?
    assert_includes output, 'already exists'
    assert_equal original, File.binread(File.join(@product_dir, 'product.yaml'))
  end

  def test_invalid_inputs_leave_no_product
    [
      ['--product', '../escape'], ['--product', 'Uppercase'],
      ['--team', 'team: bad'], ['--service', 'resources'],
      ['--slack'], ['--slack', ''], ['--slack', '#'],
      ['--slack', '##channel'], ['--slack', '#bad channel'],
      ['--slack', "#channel\ninjected: value"], ['--slack', 'channel"'],
      ['--slack', '#' + 'a' * 81],
      ['--environments', 'dev,dev'], ['--environments', 'dev,,prod'],
      ['--environments', ',dev'], ['--environments', 'dev,'],
      ['--environments', "dev\nprod"], ['--environments', 'dev, prod'],
      ['--product', 'a' * 60, '--environments', 'staging'],
      ['--bu', 'unknown'], ['--unknown'], ['--service']
    ].each do |arguments|
      output, result = generate(*arguments)
      refute result.success?, "Accepted #{arguments.inspect}: #{output}"
      assert_empty Dir.children(File.join(@root, 'namespaces/octo'))
    end
  end

  def test_broken_symlink_is_not_overwritten
    File.symlink(File.join(@root, 'missing'), @product_dir)
    output, result = generate
    refute result.success?
    assert_includes output, 'already exists'
    assert File.symlink?(@product_dir)
  end

  def test_required_arguments_and_help
    output, result = Open3.capture2e('/bin/bash', @script)
    refute result.success?
    assert_includes output, 'required'
    output, result = Open3.capture2e('/bin/bash', @script, '--help')
    assert result.success?
    assert_includes output, 'Usage:'
  end

  def test_service_generation_without_helm
    bin = File.join(@root, 'bin')
    FileUtils.mkdir_p(bin)
    %w[cat dirname mkdir rm uname].each do |utility|
      executable = ENV.fetch('PATH').split(File::PATH_SEPARATOR)
                      .map { |directory| File.join(directory, utility) }
                      .find { |path| File.executable?(path) && !File.directory?(path) }
      refute_nil executable, "Missing standard utility: #{utility}"
      File.symlink(executable, File.join(bin, utility))
    end
    File.symlink(RbConfig.ruby, File.join(bin, 'ruby'))
    output, result = Open3.capture2e({ 'PATH' => bin }, '/bin/bash', @script,
                                   '--bu', 'octo', '--product', 'sample', '--team', 'my-team',
                                   '--service', 'web', '--environments', 'dev,prod', chdir: '/')
    assert result.success?, output
    chart = File.join(@product_dir, 'web/deployment')
    assert_equal 'web', YAML.load_file(File.join(chart, 'Chart.yaml'))['name']
    assert_equal 8080, YAML.load_file(File.join(chart, 'values.yaml'))['service']['targetPort']
    %w[nonlive/dev live/prod].each do |environment|
      assert_equal "sample-#{File.basename(environment)}",
                   YAML.load_file(File.join(chart, "values/#{environment}.yaml"))['namespace']
    end
    %w[deployment service].each do |template|
      assert File.file?(File.join(chart, "templates/#{template}.yaml"))
    end
  end

  def test_product_only_generation_without_ruby
    bin = File.join(@root, 'bin')
    FileUtils.mkdir_p(bin)
    %w[cat dirname mkdir rm].each do |utility|
      executable = ENV.fetch('PATH').split(File::PATH_SEPARATOR)
                      .map { |directory| File.join(directory, utility) }
                      .find { |path| File.executable?(path) && !File.directory?(path) }
      refute_nil executable, "Missing standard utility: #{utility}"
      File.symlink(executable, File.join(bin, utility))
    end
    output, result = Open3.capture2e({ 'PATH' => bin }, '/bin/bash', @script,
                                   '--bu', 'octo', '--product', 'sample', '--team', 'my-team', '--service', 'web')
    refute result.success?
    assert_includes output, 'Ruby is required'
    refute File.exist?(@product_dir)
    output, result = Open3.capture2e({ 'PATH' => bin }, '/bin/bash', @script,
                                   '--bu', 'octo', '--product', 'sample', '--team', 'my-team')
    assert result.success?, output
    assert_equal ['product.yaml'], Dir.children(@product_dir)
    assert_equal '#my-team', product['owner']['slack']
  end

  def test_both_generators_preserve_starter_chart_metadata
    starter_file = File.join(@root, 'charts/service-starter/Chart.yaml')
    starter = YAML.load_file(starter_file)
    starter['version'] = '1.2.3'
    starter['appVersion'] = '4.5.6'
    starter['annotations'] = { 'example.com/source' => 'shared-starter' }
    File.write(starter_file, YAML.dump(starter))
    output, result = generate('--service', 'web')
    assert result.success?, output
    output, result = add_service('--service', 'backend')
    assert result.success?, output
    %w[web backend].each do |service|
      chart = YAML.load_file(File.join(@product_dir, service, 'deployment/Chart.yaml'))
      assert_equal starter.merge('name' => service, 'description' => "Starter chart for #{service}"), chart
    end
    assert_equal starter, YAML.load_file(starter_file)
  end

  def test_create_product_cleans_up_if_delegated_service_generation_fails
    FileUtils.remove_entry(File.join(@root, 'charts/service-starter'))
    output, result = generate('--service', 'web')
    refute result.success?, output
    refute File.exist?(@product_dir)
  end

  def test_helm_rendering
    skip 'Helm is not installed' unless system('helm version --short', out: File::NULL, err: File::NULL)
    output, result = generate('--service', 'web', '--environments', 'dev,prod')
    assert result.success?, output
    chart = File.join(@product_dir, 'web/deployment')
    assert_equal 'web', YAML.load_file(File.join(chart, 'Chart.yaml'))['name']
    refute File.exist?(File.join(@product_dir, '.helm'))
    %w[nonlive/dev live/prod].each do |environment|
      values = File.join(chart, "values/#{environment}.yaml")
      assert_equal "sample-#{File.basename(environment)}", YAML.load_file(values)['namespace']
      output, result = Open3.capture2e('helm', 'template', 'web', chart, '-f', values)
      assert result.success?, output
      kinds = YAML.load_stream(output).compact.map { |document| document['kind'] }
      assert_includes kinds, 'Deployment'
      assert_includes kinds, 'Service'
    end
    %w[nonlive live].each do |tier|
      output, result = Open3.capture2e('helm', 'template', 'baseline', File.join(REPO_ROOT, 'charts/app-baseline'),
                                     '-f', File.join(@product_dir, 'product.yaml'),
                                     '--set', "targetCluster=container-platform-octo-#{tier}")
      assert result.success?, output
      namespaces = YAML.load_stream(output).compact.select { |document| document['kind'] == 'Namespace' }
      environment = tier == 'live' ? 'prod' : 'dev'
      assert_equal ["sample-#{environment}"], namespaces.map { |namespace| namespace['metadata']['name'] }
    end
  end
end